defmodule Egapp.XMPP.Stanza do
  def iq(id, type, content) do
    {
      :iq,
      [id: id, type: type, from: 'localhost'],
      [content]
    }
  end
end
