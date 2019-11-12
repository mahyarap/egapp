defmodule Egapp.XMPP.Stanza do
  alias Egapp.XMPP.Element

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
  def iq({%{"type" => "get"} = attrs, [{:xmlel, "query", child_attrs, data}]}) do
    Element.query({to_map(child_attrs), data, attrs})
  end
  def iq({%{"type" => "get"} = attrs, [{:xmlel, "vCard", _child_attrs, _data}]}) do
    iq(attrs["id"], 'result',
      {
        :vCard,
        [xmlns: 'vcard-temp'],
        []
      }
    )
  end
  def iq({%{"type" => "set"} = attrs, [{:xmlel, "query", _child_attrs, _data}]}) do
    """
    <iq type='result' id='#{attrs["id"]}'/>
    """
  end
  def iq({%{"type" => "get"} = attrs, [{:xmlel, "ping", _child_attrs, _data}]}) do
    iq(attrs["id"], 'result')
  end
  def iq({%{"type" => "set"} = attrs, [{:xmlel, "bind", _child_attrs, _data}]}) do
    iq(attrs["id"], 'result', Element.bind('foo@localhost/4db06f06-1ea4-11dc-aca3-000bcd821bfb'))
  end
  def iq({%{"type" => "set"} = attrs, [{:xmlel, "session", _child_attrs, _data}]}) do
    iq(attrs["id"], 'result')
  end

  def message({attrs, [{:xmlel, "composing", _child_attrs, _data}]}) do
    {
      :message,
      [
        from: 'alice@wonderland.lit/orchard',
        id: '#{attrs["id"]}',
        to: 'foo@localhost/4db06f06-1ea4-11dc-aca3-000bcd821bfb',
        type: 'chat',
        "xml:lang": 'en'
      ],
      ['fooo']
    }
  end
  def message({attrs, [{:xmlel, "paused", _child_attrs, _data}]}) do
    {
      :message,
      [
        from: 'alice@wonderland.lit/orchard',
        id: '#{attrs["id"]}',
        to: 'foo@localhost/4db06f06-1ea4-11dc-aca3-000bcd821bfb',
        type: 'chat',
        "xml:lang": 'en'
      ],
      ['fooo']
    }
  end
  def message({attrs, [{:xmlel, "active", _child_attrs, _data}, _foo]}) do
    {
      :message,
      [
        from: 'alice@wonderland.lit/orchard',
        id: '#{attrs["id"]}',
        to: 'foo@localhost/4db06f06-1ea4-11dc-aca3-000bcd821bfb',
        type: 'chat',
        "xml:lang": 'en'
      ],
      ['fooo']
    }
  end

  defp to_map(attrs) do
    Enum.into(attrs, %{})
  end
end
