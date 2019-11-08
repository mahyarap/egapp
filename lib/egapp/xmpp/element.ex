defmodule Egapp.XMPP.Element do
  def features(content) do
    {
      :"stream:features",
      [content]
    }
  end

  def bind(jid \\ nil) do
    content = 
      if jid do
        [{:jid, [jid]}]
      else
        []
      end

    {
      :bind,
      [xmlns: 'urn:ietf:params:xml:ns:xmpp-bind'],
      content
    }
  end

  def mechanisms do
    {
      :mechanisms,
      [xmlns: 'urn:ietf:params:xml:ns:xmpp-sasl'],
      [
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

  def session do
    {
      :session,
      [xmlns: 'urn:ietf:params:xml:ns:xmpp-session'],
      []
    }
  end
end
