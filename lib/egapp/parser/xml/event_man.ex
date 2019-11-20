defmodule Egapp.Parser.XML.EventMan do
  require Logger
  require Egapp.Constants, as: Const
  alias Egapp.XMPP.Stream
  alias Egapp.XMPP.Element

  @behaviour GenServer

  @impl true
  def init(args) do
    state = %{
      mod: Keyword.fetch!(args, :mod),
      to: Keyword.fetch!(args, :to),
      client_props: %{}
    }

    {:ok, state}
  end

  @impl true
  def handle_call(
        {"stream:stream",
          %{"xmlns:stream" => Const.xmlns_stream, "version" => Const.xmpp_version} = attrs},
        _from,
        state
      ) do
    lang = Map.get(attrs, "xml:lang", "en")
    state = put_in(state, [:client_props, :lang], lang)
    id = Enum.random(10_000_000..99_999_999)

    features =
      if Map.get(state.client_props, :is_authenticated) do
        [Element.bind(), Element.session()]
      else
        [Element.mechanisms()]
      end

    content = Element.features(features)

    resp =
      Stream.stream(id, from: Map.get(attrs, "from"), content: content)
      |> :xmerl.export_simple_element(:xmerl_xml)
      # Remove </stream:stream> which is automatically created
      |> Enum.reverse()
      |> tl()
      |> Enum.reverse()

    apply(state.mod, :send, [state.to, prepend_xml_decl(resp)])
    {:reply, :continue, state}
  end

  def handle_call(
        {"stream:stream", %{"xmlns:stream" => _, "version" => Const.xmpp_version} = attrs},
        _from,
        state
      ) do
    lang = Map.get(attrs, "xml:lang", "en")
    id = Enum.random(10_000_000..99_999_999)
    content = Stream.invalid_namespace_error()

    resp =
      Stream.stream(id, from: Map.get(attrs, "from"), lang: lang, content: content)
      |> :xmerl.export_simple_element(:xmerl_xml)

    apply(state.mod, :send, [state.to, prepend_xml_decl(resp)])
    {:stop, :normal, :stop, state}
  end

  def handle_call(
        {"stream:stream", %{"xmlns:stream" => _, "version" => _} = attrs},
        _from,
        state
      ) do
    lang = Map.get(attrs, "xml:lang", "en")
    id = Enum.random(10_000_000..99_999_999)
    content = Stream.unsupported_version_error()

    resp =
      Stream.stream(id, from: Map.get(attrs, "from"), lang: lang, content: content)
      |> :xmerl.export_simple_element(:xmerl_xml)

    apply(state.mod, :send, [state.to, resp])
    {:reply, :stop, state}
  end

  def handle_call({"stream:stream", attrs}, _from, state) do
    resp =
      cond do
        Map.get(attrs, "xmlns:stream") != Const.xmlns_stream ->
          """
          <stream:error>
          <invalid-namespace
          xmlns="urn:ietf:params:xml:ns:xmpp-streams"/>
          </stream:error>
          """

        not Map.has_key?(attrs, "xmlns") ->
          """
          <stream:error>
          <invalid-namespace
          xmlns="urn:ietf:params:xml:ns:xmpp-streams"/>
          </stream:error>
          """

        not Map.has_key?(attrs, "version") ->
          """
          <stream:error>
          <unsupported-version
          xmlns='urn:ietf:params:xml:ns:xmpp-streams'/>
          </stream:error>
          """

        true ->
          "should not get here"
      end

    apply(state.mod, :send, [state.to, resp])
    {:noreply, state}
  end

  def handle_call({"stream", _attrs}, _from, state) do
    resp = """
    <stream:error>
    <bad-namespace-prefix
    xmlns="urn:ietf:params:xml:ns:xmpp-streams"/>
    </stream:error>
    """

    apply(state.mod, :send, [state.to, resp])
    {:noreply, state}
  end

  def handle_call({"error:parsing", error}, _from, state) do
    resp =
      case error do
        {4, "not well-formed (invalid token)"} ->
          "4"

        {7, "mismatched tag"} ->
          "7"

        {27, "unbound prefix"} ->
          """
          <stream:error>
          <invalid-xml
          xmlns="urn:ietf:params:xml:ns:xmpp-streams"/>
          </stream:error>
          """

        _ ->
          "3"
      end

    apply(state.mod, :send, [state.to, resp])
    {:stop, :normal, state}
  end

  def handle_call({"auth", attrs, data}, _from, state) do
    Logger.debug("c2s: #{inspect({"auth", attrs, data})}")
    result = Egapp.SASL.authenticate!(attrs["mechanism"], data)
    state = put_in(state, [:client_props, :is_authenticated], true)
    resp =
      result
      |> :xmerl.export_simple_element(:xmerl_xml)
    apply(state.mod, :send, [state.to, resp])
    action =
      case result do
        {:success, _, _} -> :reset
        {:challenge, _, _} -> :continue
      end
    {:reply, action, state}
  end

  defp md5(iodata) do
    :crypto.hash(:md5, iodata)
  end

  defp md5_hex(iodata) do
    md5(iodata) |> Base.encode16(case: :lower)
  end

  def handle_call({"response", attrs, [xmlcdata: digest_response]}, _from, state) do
    decoded =
      digest_response
      |> Base.decode64!()
      |> String.split(",")
      |> Enum.map(&String.split(&1, "=", parts: 2))
      |> Map.new(fn [k, v] -> {k, String.trim(v, ~s("))} end)

    IO.inspect decoded

    a1 = [
      md5([decoded["username"], ':', decoded["realm"], ':', 'bar']),
      ':', decoded["nonce"], ':', decoded["cnonce"]
    ]
    a2 = ['AUTHENTICATE', ':', decoded["digest-uri"]]

    response_value = md5_hex([
      md5_hex(a1),
      ':',
      [decoded["nonce"], ':', decoded["nc"], ':', decoded["cnonce"], ':', decoded["qop"]],
      ':',
      md5_hex(a2)
    ])

    IO.inspect response_value

    rspauth = md5_hex([
      md5_hex(a1),
      ':',
      [decoded["nonce"], ':', decoded["nc"], ':', decoded["cnonce"], ':', decoded["qop"]],
      md5_hex(tl(a2))
    ])

    result = {
      :success,
      [xmlns: Const.xmlns_sasl],
      ["rspauth=" <> rspauth |> Base.encode64() |> String.to_charlist()]
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
          [{:xmlel, tag_name, to_map(child_attrs), child_data}]
      end

    resp =
      Egapp.XMPP.Stanza.iq({attrs, child_node})
      |> :xmerl.export_simple_element(:xmerl_xml)

    apply(state.mod, :send, [state.to, resp])
    {:reply, :continue, state}
  end

  def handle_call({"presence", attrs, data}, _from, state) do
    Logger.debug("c2s: #{inspect({"iq", attrs, data})}")
    resp =
      Egapp.XMPP.Stanza.presence({attrs, data})
      |> :xmerl.export_simple_element(:xmerl_xml)
    apply(state.mod, :send, [state.to, resp])
    {:reply, :continue, state}
  end

  def handle_call({"message", attrs, data}, _from, state) do
    resp = Egapp.XMPP.Stanza.message({attrs, data})
    resp = if resp, do: :xmerl.export_simple_element(resp, :xmerl_xml), else: []

    apply(state.mod, :send, [state.to, resp])
    {:reply, :continue, state}
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

  defp prepend_xml_decl(content) do
    ['<?xml version="1.0"?>' | content]
  end

  defp to_map(attrs) do
    Enum.into(attrs, %{})
  end
end
