defmodule Egapp.Parser.XML.EventMan do
  require Logger
  require Ecto.Query
  require Egapp.Constants, as: Const
  alias Egapp.XMPP.Stream
  alias Egapp.XMPP.Stanza

  @behaviour GenServer

  @impl true
  def init(args) do
    state = %{
      mod: Keyword.fetch!(args, :mod),
      to: Keyword.fetch!(args, :to),
      client: %{
        is_authenticated: false
      }
    }

    {:ok, state}
  end

  @impl true
  @doc """
  Handles the initial stream header.

  RFC6120 4.1
  RFC6120 4.2
  RFC6120 4.7
  RFC6120 4.8
  """
  def handle_call({"stream:stream", attrs}, _from, state) do
    {status, resp} = Stream.stream(attrs, state)
    apply(state.mod, :send, [state.to, resp])

    case status do
      :ok -> {:reply, :continue, state}
      :error -> {:stop, :normal, state}
    end
  end

  def handle_call({"stream", attrs}, _from, state) do
    resp = Stream.error(:bad_namespace_prefix, attrs, state)
    apply(state.mod, :send, [state.to, resp])
    {:stop, :normal, state}
  end

  def handle_call({"auth", attrs, data}, _from, state) do
    Logger.debug("c2s: #{inspect({"auth", attrs, data})}")

    {action, resp, state} =
      case Stream.auth(attrs, data, state) do
        {:ok, resp, state} -> {:reset, resp, state}
        {:error, resp, state} -> {:continue, resp, state}
      end

    apply(state.mod, :send, [state.to, resp])
    {:reply, action, state}
  end

  def handle_call({"response", _attrs, [xmlcdata: digest_response]}, _from, state) do
    rspauth = Egapp.SASL.Digest.validate_digest_response(digest_response)

    result = {
      :success,
      [xmlns: Const.xmlns_sasl()],
      [("rspauth=" <> rspauth) |> Base.encode64() |> String.to_charlist()]
    }

    resp =
      result
      |> :xmerl.export_simple_element(:xmerl_xml)

    apply(state.mod, :send, [state.to, resp])
    {:reply, :reset, state}
  end

  def handle_call({"iq", attrs, data}, _from, state) do
    Logger.debug("c2s: #{inspect({"iq", attrs, data})}")

    child_node =
      case data do
        [{:xmlel, tag_name, child_attrs, child_data}] ->
          {tag_name, to_map(child_attrs), child_data}
      end

    {status, resp} = Egapp.XMPP.Stanza.iq(attrs, child_node, state)
    apply(state.mod, :send, [state.to, resp])

    case status do
      :ok -> {:reply, :continue, state}
      :error -> {:stop, :normal, state}
    end
  end

  @doc """
  Handles initial presence.

  RFC6121 4.2.2
  RFC6121 4.2.3
  """
  def handle_call({"presence", attrs, data}, _from, state) do
    Logger.debug("c2s: #{inspect({"presence", attrs, data})}")

    contacts = Stanza.presence(attrs, data, state)
    for {conn, resp} <- contacts, do: apply(state.mod, :send, [conn, resp])
    {:reply, :continue, state}
  end

  def handle_call({"message", attrs, data}, _from, state) do
    Logger.debug("c2s: #{inspect({"message", attrs, data})}")

    children =
      data
      |> Enum.map(fn child ->
        {:xmlel, tag_name, attrs, data} = child
        {tag_name, to_map(attrs), data}
      end)

    {:ok, {to, resp}} = Egapp.XMPP.Stanza.message(attrs, children, state)
    apply(state.mod, :send, [to, resp])
    {:reply, :continue, state}
  end

  def handle_call({:error, error}, _from, state) do
    id = Enum.random(10_000_000..99_999_999)

    content =
      case error do
        {4, "not well-formed (invalid token)"} -> "4"
        {7, "mismatched tag"} -> "7"
        {27, "unbound prefix"} -> "8"
        {8, "duplicate attribute"} -> "9"
        _ -> IO.inspect(error)
      end

    resp =
      Stream.stream(content, id: id)
      |> :xmerl.export_simple_element(:xmerl_xml)

    apply(state.mod, :send, [state.to, resp])
    {:stop, :normal, state}
  end

  def handle_call({_tag_name, _attrs}, _from, state) do
    resp = """
    <stream:error>
    <invalid-xml
    xmlns="urn:ietf:params:xml:ns:xmpp-streams"/>
    </stream:error>
    </stream:stream>
    """

    apply(state.mod, :send, [state.to, resp])
    {:noreply, state}
  end

  def handle_call({"end"}, _from, state) do
    resp = ['</stream:stream>']
    apply(state.mod, :send, [state.to, resp])
    {:stop, :normal, state}
  end

  defp to_map(attrs) do
    Enum.into(attrs, %{})
  end
end
