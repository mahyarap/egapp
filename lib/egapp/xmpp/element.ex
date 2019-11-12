defmodule Egapp.XMPP.Element do
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

  def session do
    {
      :session,
      [xmlns: 'urn:ietf:params:xml:ns:xmpp-session'],
      []
    }
  end
end
