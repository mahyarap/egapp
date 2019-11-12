defmodule Egapp.XMPP.Element do
  alias Egapp.XMPP.Stanza

  @doc """
  RFC6120 4.3.2
  """
  def features(content) do
    {
      :"stream:features",
      content
    }
  end

  @doc """
  RFC6120 7.4
  RFC6120 7.6.1
  """
  def bind(jid \\ nil) do
    content = if jid do [{:jid, [jid]}] else [] end

    {
      :bind,
      [xmlns: 'urn:ietf:params:xml:ns:xmpp-bind'],
      content
    }
  end

  @doc """
  RFC6120 6.3.3
  RFC6120 6.4.1
  """
  def mechanisms do
    {
      :mechanisms,
      [xmlns: 'urn:ietf:params:xml:ns:xmpp-sasl'],
      [
        # Server preference order
        {:mechanism, ['ANONYMOUS']},
        {:mechanism, ['PLAIN']}
      ]
    }
  end

  def success do
    {
      :success,
      [xmlns: 'urn:ietf:params:xml:ns:xmpp-sasl'],
      []
    }
  end

  @doc """
  RFC3921 3
  """
  def session do
    {
      :session,
      [xmlns: 'urn:ietf:params:xml:ns:xmpp-session'],
      []
    }
  end

  def query({%{"xmlns" => "jabber:iq:auth"}, [{:xmlel, "username", attrs, data}], state}) do
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
  def query({%{"xmlns" => "http://jabber.org/protocol/disco#items"}, [], state}) do
    Stanza.iq(state["id"], 'result',
      {
        :query,
        [xmlns: 'http://jabber.org/protocol/disco#items'],
        []
      }
    )
  end
  def query({%{"xmlns" => "http://jabber.org/protocol/disco#info"}, [], %{"to" => "localhost"} = state}) do
    Stanza.iq(state["id"], 'result',
      {
        :query,
        [xmlns: 'http://jabber.org/protocol/disco#info'],
        [{:identity, [category: 'server', type: 'im'], []}]
      }
    )
  end
  def query({%{"xmlns" => "jabber:iq:roster"}, [], state}) do
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
  end
  def query({%{"xmlns" => "http://jabber.org/protocol/bytestreams"}, [], state}) do
    {
      :iq,
      [
        id: state["id"],
        from: 'proxy.eu.jabber.org',
        to: 'foo@localhost/4db06f06-1ea4-11dc-aca3-000bcd821bfb',
        type: 'error'
      ],
      [
        {
          :error,
          [type: 'cancel'],
          [
            {
              :"feature-not-implemented",
              [xmlns: 'urn:ietf:params:xml:ns:xmpp-stanzas'],
              []
            }
          ]
        }
      ]
    }
  end
end
