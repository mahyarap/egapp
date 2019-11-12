defmodule Egapp.XMPP.Element do
  require Egapp.Constants, as: Const

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
    content =
      if jid do
        [{:jid, [jid]}]
      else
        []
      end

    {
      :bind,
      [xmlns: Const.xmlns_bind],
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
      [xmlns: Const.xmlns_sasl],
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
      [xmlns: Const.xmlns_sasl],
      []
    }
  end

  @doc """
  RFC3921 3
  """
  def session do
    {
      :session,
      [xmlns: Const.xmlns_session],
      []
    }
  end

  def query(attrs, content \\ nil) do
    {
      :query,
      attrs,
      content || []
    }
  end
end
