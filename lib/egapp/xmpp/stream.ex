defmodule Egapp.XMPP.Stream do
  @xmlns_stream 
  def stream(id, lang, content) do
    {
      :"stream:stream",
      [
        from: 'localhost',
        id: id,
        to: 'foo@localhost',
        version: '1.0',
        "xml:lang": lang,
        xmlns: 'jabber:client',
        "xmlns:stream": 'http://etherx.jabber.org/streams',
      ],
      [content]
    }
  end
end
