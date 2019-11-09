defmodule Egapp.XMPP.Stanza do
  def iq(id, type, content \\ nil) do
    {
      :iq,
      [id: id, type: type, from: 'localhost'],
      if content do
        [content]
      else
        []
      end
    }
  end
end
