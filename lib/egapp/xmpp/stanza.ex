defmodule Egapp.XMPP.Stanza do
  require Egapp.Constants, as: Const
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

  def iq(
        {%{"type" => "get"} = attrs,
         [{:xmlel, "query", %{"xmlns" => Const.xmlns_disco_items}, data}]}
      ) do
    iq(attrs["id"], 'result', Element.query(xmlns: Const.xmlns_disco_items))
  end

  def iq(
        {%{"type" => "get"} = attrs,
         [{:xmlel, "query", %{"xmlns" => Const.xmlns_disco_info}, data}]}
      ) do
    iq(
      attrs["id"],
      'result',
      Element.query(
        [xmlns: Const.xmlns_disco_info],
        [{:identity, [category: 'server', type: 'im'], []}]
      )
    )
  end

  def iq(
        {%{"type" => "get"} = attrs, [{:xmlel, "query", %{"xmlns" => Const.xmlns_roster}, data}]}
      ) do
    iq(
      attrs["id"],
      'result',
      Element.query(
        [xmlns: Const.xmlns_disco_info],
        [{:item, [jid: 'alice@wonderland.lit', subscription: 'both'], []}]
      )
    )
  end

  def iq(
        {%{"type" => "get"} = attrs,
         [{:xmlel, "query", %{"xmlns" => Const.xmlns_bytestreams}, data}]}
      ) do
    iq(
      attrs["id"],
      'result',
      Element.query(
        [xmlns: Const.xmlns_disco_info],
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
      )
    )
  end

  def iq({%{"type" => "get"} = attrs, [{:xmlel, "vCard", _child_attrs, _data}]}) do
    iq(attrs["id"], 'result', {
      :vCard,
      [xmlns: 'vcard-temp'],
      []
    })
  end

  def iq({%{"type" => "get"} = attrs, [{:xmlel, "ping", _child_attrs, _data}]}) do
    iq(attrs["id"], 'result')
  end

  def iq({%{"type" => "set"} = attrs, [{:xmlel, "query", _child_attrs, _data}]}) do
    """
    <iq type='result' id='#{attrs["id"]}'/>
    """
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
