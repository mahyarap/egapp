defmodule Egapp.Parser.XML.EventMan do
  require Logger

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
  def handle_call({"auth", attrs, data}, _from,  state) do
    Logger.debug("c2s: #{inspect {"auth", attrs, data}}")
    IO.inspect Egapp.SASL.authenticate!(attrs["mechanism"], Keyword.fetch!(data, :xmlcdata))
    state = Map.put(state, :client_props, Map.put(state.client_props, :is_authenticated, true))
    resp = """
    <success xmlns='urn:ietf:params:xml:ns:xmpp-sasl'/>
    """
    apply(state.mod, :send, [state.to, resp])
    {:reply, :reset, state}
  end

  @impl true
  def handle_cast({"stream:stream",
    %{"xmlns" => @xmlns_c2s, "version" => @xmpp_version} = attrs},
    state)
  do
    lang = Map.get(attrs, "xml:lang", "en")
    state = Map.put(state, :client_props, Map.put(state.client_props, :lang, lang))
    resp = """
    <?xml version="1.0"?>
    <stream:stream
    from="localhost"
    id="++TR84Sm6A3hnt3Q065SnAbbk3Y="
    to="foo@localhost"
    version="1.0"
    xml:lang="#{lang}"
    xmlns="jabber:client"
    xmlns:stream="http://etherx.jabber.org/streams">
    """
    resp = resp <>
      if Map.get(state.client_props, :is_authenticated) do
        """
        <stream:features/>
        """
      else
        """
        <stream:features>
        <mechanisms xmlns='urn:ietf:params:xml:ns:xmpp-sasl'>
        <mechanism>ANONYMOUS</mechanism>
        <mechanism>PLAIN</mechanism>
        </mechanisms>
        </stream:features>
        """
      end
    apply(state.mod, :send, [state.to, resp])
    {:noreply, state}
  end
  def handle_cast({"stream:stream", %{"xmlns" => _, "version" => @xmpp_version}},
    state)
  do
    resp = """
    <stream:error>
    <invalid-namespace
    xmlns="urn:ietf:params:xml:ns:xmpp-streams"/>
    </stream:error>
    """
    apply(state.mod, :send, [state.to, resp])
    {:noreply, state}
  end
  def handle_cast({"stream:stream", %{"xmlns" => _, "version" => _}}, state) do
    resp = """
    <stream:error>
    <unsupported-version
    xmlns='urn:ietf:params:xml:ns:xmpp-streams'/>
    </stream:error>
    """
    apply(state.mod, :send, [state.to, resp])
    {:noreply, state}
  end
  def handle_cast({"stream:stream", attrs}, state) do
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
  def handle_cast({"stream", _attrs}, state) do
    resp = """
    <stream:error>
    <bad-namespace-prefix
    xmlns="urn:ietf:params:xml:ns:xmpp-streams"/>
    </stream:error>
    """
    apply(state.mod, :send, [state.to, resp])
    {:noreply, state}
  end
  def handle_cast({"error:parsing", error}, state) do
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
  def handle_cast({"iq", attrs, data}, state) do
    Logger.debug("c2s: #{inspect {"iq", attrs, data}}")
    resp = IqStanza.handle({attrs, data})
    apply(state.mod, :send, [state.to, resp])
    {:noreply, state}
  end
  def handle_cast({"message", _attrs, _data}, state) do
    resp = """
    <message>hoy</message>
    """
    apply(state.mod, :send, [state.to, resp])
    {:noreply, state}
  end
  def handle_cast({_tag_name, _attrs}, state) do
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
end

defmodule IqStanza do
  def handle({%{"type" => "get"} = attrs, [{:xmlel, "query", child_attrs, data}]}) do
    QueryStanza.handle({to_map(child_attrs), data, attrs})
  end

  def handle({%{"type" => "set"} = attrs, [{:xmlel, "query", child_attrs, data}]}) do
    """
    <iq type='result' id='#{attrs["id"]}'/>
    """
  end

  defp to_map(attrs) do
    Enum.into(attrs, %{})
  end
end

defmodule QueryStanza do
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
    """
    <iq type='result'
    from='localhost'
    to='romeo@montague.net/orchard'
    id='#{state["id"]}'>
    <query xmlns='http://jabber.org/protocol/disco#items'>
    <item jid='people.shakespeare.lit'
          name='Directory of Characters'/>
    <item jid='plays.shakespeare.lit'
          name='Play-Specific Chatrooms'/>
    <item jid='mim.shakespeare.lit'
          name='Gateway to Marlowe IM'/>
    <item jid='words.shakespeare.lit'
          name='Shakespearean Lexicon'/>
    <item jid='globe.shakespeare.lit'
          name='Calendar of Performances'/>
    <item jid='headlines.shakespeare.lit'
          name='Latest Shakespearean News'/>
    <item jid='catalog.shakespeare.lit'
          name='Buy Shakespeare Stuff!'/>
    <item jid='en2fr.shakespeare.lit'
          name='French Translation Service'/>
    </query>
    </iq>
    """
  end
end
