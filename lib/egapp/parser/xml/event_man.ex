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
          Element.bind()
        else
          Element.mechanisms()
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
    resp = IqStanza.handle({attrs, data})
    apply(state.mod, :send, [state.to, resp])
    {:reply, :continue, state}
  end
  def handle_call({"presence", attrs, data}, _from, state) do
    Logger.debug("c2s: #{inspect {"iq", attrs, data}}")
    # apply(state.mod, :send, [state.to, resp])
    {:reply, :continue, state}
  end
  def handle_call({"message", attrs, _data}, _from, state) do
    resp = """
    <message
        from='bar@localhost/orchard'
        id='#{attrs["id"]}'
        to='foo@localhost/4db06f06-1ea4-11dc-aca3-000bcd821bfb'
        type='chat'
        xml:lang='en'>
      <body>Neither, fair saint, if either thee dislike.</body>
    </message>\
    """
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

defmodule IqStanza do
  alias Egapp.XMPP.Stanza
  alias Egapp.XMPP.Element

  def handle({%{"type" => "get"} = attrs, [{:xmlel, "query", child_attrs, data}]}) do
    QueryStanza.handle({to_map(child_attrs), data, attrs})
  end
  def handle({%{"type" => "get"} = attrs, [{:xmlel, "vCard", _child_attrs, _data}]}) do
    Stanza.iq(attrs["id"], 'result',
      {
        :vCard,
        [xmlns: 'vcard-temp'],
        []
      }
    )
    |> :xmerl.export_simple_element(:xmerl_xml)
  end
  def handle({%{"type" => "set"} = attrs, [{:xmlel, "query", _child_attrs, _data}]}) do
    """
    <iq type='result' id='#{attrs["id"]}'/>
    """
  end
  def handle({%{"type" => "get"} = attrs, [{:xmlel, "ping", _child_attrs, _data}]}) do
    Stanza.iq(attrs["id"], 'result')
    |> :xmerl.export_simple_element(:xmerl_xml)
  end
  def handle({%{"type" => "set"} = attrs, [{:xmlel, "bind", _child_attrs, _data}]}) do
    Stanza.iq(attrs["id"], 'result', Element.bind('foo@localhost/4db06f06-1ea4-11dc-aca3-000bcd821bfb'))
    |> :xmerl.export_simple_element(:xmerl_xml)
  end
  def handle({%{"type" => "set"} = attrs, [{:xmlel, "session", _child_attrs, _data}]}) do
    Stanza.iq(attrs["id"], 'result', Element.session())
    |> :xmerl.export_simple_element(:xmerl_xml)
  end

  defp to_map(attrs) do
    Enum.into(attrs, %{})
  end
end

defmodule QueryStanza do
  alias Egapp.XMPP.Stanza

  def handle({%{"xmlns" => "jabber:iq:auth"}, [{:xmlel, "username", attrs, data}], state}) do
    IO.inspect {attrs, data, state}
    """
    <iq type='result' id='#{state["id"]}'>
    <query xmlns='jabber:iq:auth'>
    <username/>
    <password/>
    <resource/>
    </query>
    </iq>
    """
  end
  def handle({%{"xmlns" => "http://jabber.org/protocol/disco#items"}, [], state}) do
    Stanza.iq(state["id"], 'result',
      {
        :query,
        [xmlns: 'http://jabber.org/protocol/disco#items'],
        []
      }
    )
    |> :xmerl.export_simple_element(:xmerl_xml)
  end
  def handle({%{"xmlns" => "http://jabber.org/protocol/disco#info"}, [], %{"to" => "localhost"} = state}) do
    Stanza.iq(state["id"], 'result',
      {
        :query,
        [xmlns: 'http://jabber.org/protocol/disco#info'],
        [{:identity, [category: 'server', type: 'im'], []}]
      }
    )
    |> :xmerl.export_simple_element(:xmerl_xml)
  end
  def handle({%{"xmlns" => "jabber:iq:roster"}, [], state}) do
    # Stanza.iq(state["id"], 'result',
    #   {
    #     :query,
    #     [xmlns: 'jabber:iq:roster'],
    #     [{:item, [jid: 'alice@wonderland.lit', subscription: 'both'], []}]
    #   }
    # )
    {
      :iq,
      [id: state["id"], type: 'result', to: 'foo@localhost/4db06f06-1ea4-11dc-aca3-000bcd821bfb'],
      [
        {
          :query,
          [xmlns: 'jabber:iq:roster'],
          [{:item, [jid: 'alice@wonderland.lit', subscription: 'both'], []}]
        }
      ]
    }
    |> :xmerl.export_simple_element(:xmerl_xml)
  end
  def handle({%{"xmlns" => "http://jabber.org/protocol/bytestreams"}, [], state}) do
    """
    <iq from="proxy.eu.jabber.org"
    id='#{state["id"]}'
    to="foo@localhost/4db06f06-1ea4-11dc-aca3-000bcd821bfb"
    type='error'>
    <error type='cancel'>
      <feature-not-implemented
          xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>
    </error>
    </iq>\
    """
  end
end
