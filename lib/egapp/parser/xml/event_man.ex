defmodule Egapp.Parser.XML.EventMan do
  require Logger
  require Ecto.Query
  require Egapp.Constants, as: Const
  alias Egapp.XMPP.Stream
  alias Egapp.XMPP.Stanza
  alias Egapp.XMPP.Element
  alias Egapp.JidConnRegistry

  @behaviour GenServer

  @bare_jid_re ~r|^(?<localpart>[^@]+)@(?<domainpart>[^/]+)|

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

    result =
      case Egapp.SASL.authenticate!(attrs["mechanism"], data) do
        {:ok, user} ->
          state =
            state
            |> put_in([:client, :is_authenticated], true)
            |> put_in([:client, :id], user.id)
            |> put_in([:client, :bare_jid], user.username <> "@egapp.im")
            |> put_in([:client, :resource], Enum.random(10_000_000..99_999_999))

          JidConnRegistry.put(user.username <> "@egapp.im", state.to)
          {:reset, Egapp.XMPP.Element.success(), state}

        {:error, _} ->
          {:continue, Egapp.XMPP.Element.failure({:"not-authorized", []}), state}

        {:challenge, _} ->
          {:continue, nil, state}
      end

    {action, element, state} = result

    resp =
      element
      |> :xmerl.export_simple_element(:xmerl_xml)

    apply(state.mod, :send, [state.to, resp])
    {:reply, action, state}
  end

  def handle_call({"response", attrs, [xmlcdata: digest_response]}, _from, state) do
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
    bare_jid = Regex.named_captures(@bare_jid_re, attrs["to"])
    to = JidConnRegistry.get(bare_jid["localpart"] <> "@" <> bare_jid["domainpart"])
    attrs = Map.put(attrs, "from", "#{state.client.bare_jid}/#{state.client.resource}")
    resp = Egapp.XMPP.Stanza.message({attrs, data})
    resp = if resp, do: :xmerl.export_simple_element(resp, :xmerl_xml), else: []

    apply(state.mod, :send, [to, resp])
    {:reply, :continue, state}
  end

  def handle_call({:error, error}, _from, state) do
    id = Enum.random(10_000_000..99_999_999)

    content =
      case error do
        {4, "not well-formed (invalid token)"} -> "4"
        {7, "mismatched tag"} -> "7"
        {27, "unbound prefix"} -> Egapp.XMPP.Stream.bad_format_error()
        {8, "duplicate attribute"} -> Egapp.XMPP.Stream.bad_format_error()
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

  defp prepend_xml_decl(content) do
    ['<?xml version="1.0"?>' | content]
  end

  defp to_map(attrs) do
    Enum.into(attrs, %{})
  end
end
