defmodule Egapp.XMPP.Stream do
  @doc """
  RFC6120 4.7
  RFC6120 4.7.1
  RFC6120 4.7.2
  RFC6120 4.7.3
  RFC6120 4.7.4
  RFC6120 4.7.5
  RFC6120 4.8.1
  RFC6120 4.8.2
  RFC6120 4.8.3
  """
  def stream(id, opts) do
    attrs = [
      from: 'localhost',
      id: id,
      version: '1.0',
      "xml:lang": Keyword.get(opts, :lang) || 'en',
      xmlns: 'jabber:client',
      "xmlns:stream": 'http://etherx.jabber.org/streams',
    ]
    {from, opts} = Keyword.pop(opts, :from)
    attrs = if from, do: [{:to, from} | attrs], else: attrs

    {content, opts} = Keyword.pop(opts, :content)
    content = if content, do: [content], else: []

    {
      :"stream:stream",
      attrs,
      content
    }
  end

  defp error(err) do
    {
      :"stream:error",
      [],
      [err]
    }
  end

  def invalid_namespace_error do
    error({
      :"invalid-namespace",
      [xmlns: 'urn:ietf:params:xml:ns:xmpp-streams'],
      []
    })
  end

  def unsupported_version_error do
    error({
      :"unsupported-version",
      [xmlns: 'urn:ietf:params:xml:ns:xmpp-streams'],
      []
    })
  end
end
