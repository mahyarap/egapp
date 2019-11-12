defmodule Egapp.Parser.XML.EventMan do
  require Logger
  alias Egapp.XMPP.Stream
  alias Egapp.XMPP.Element

  @behaviour GenServer

  @xmlns_stream "http://etherx.jabber.org/streams"
  @xmlns_c2s "jabber:client"
  @xmpp_version "1.0"

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
  def handle_call({"stream:stream",
    %{"xmlns:stream" => @xmlns_stream, "version" => @xmpp_version} = attrs},
    _from,
    state)
  do
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
    apply(state.mod, :send, [state.to, ['<?xml version="1.0"?>' | resp]])
    {:reply, :continue, state}
  end
  def handle_call({"stream:stream",
    %{"xmlns:stream" => _, "version" => @xmpp_version} = attrs},
    _from,
    state)
  do
    lang = Map.get(attrs, "xml:lang", "en")
    id = Enum.random(10_000_000..99_999_999)
    content = Stream.invalid_namespace_error()

    resp =
      Stream.stream(id, from: Map.get(attrs, "from"), lang: lang, content: content)
      |> :xmerl.export_simple_element(:xmerl_xml)
    apply(state.mod, :send, [state.to, prepend_xml_decl(resp)])
    {:stop, :normal, :stop, state}
  end
  def handle_call({"stream:stream", %{"xmlns:stream" => _, "version" => _} = attrs},
    _from,
    state)
  do
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
      Map.get(attrs, "xmlns:stream") != @xmlns_stream ->
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
  def handle_call({"auth", attrs, data}, _from,  state) do
    Logger.debug("c2s: #{inspect {"auth", attrs, data}}")
    IO.inspect Egapp.SASL.authenticate!(attrs["mechanism"], Keyword.fetch!(data, :xmlcdata))
    state = Map.put(state, :client_props, Map.put(state.client_props, :is_authenticated, true))
    resp = :xmerl.export_simple_element(Element.success(), :xmerl_xml)
    apply(state.mod, :send, [state.to, resp])
    {:reply, :reset, state}
  end
  def handle_call({"iq", attrs, data}, _from, state) do
    Logger.debug("c2s: #{inspect {"iq", attrs, data}}")
    resp =
      Egapp.XMPP.Stanza.iq({attrs, data})
      |> :xmerl.export_simple_element(:xmerl_xml)
    apply(state.mod, :send, [state.to, resp])
    {:reply, :continue, state}
  end
  def handle_call({"presence", attrs, data}, _from, state) do
    Logger.debug("c2s: #{inspect {"iq", attrs, data}}")
    # apply(state.mod, :send, [state.to, resp])
    {:reply, :continue, state}
  end
  def handle_call({"message", attrs, data}, _from, state) do
    resp =
      Egapp.XMPP.Stanza.message({attrs, data})
      |>:xmerl.export_simple_element(:xmerl_xml)
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
end
