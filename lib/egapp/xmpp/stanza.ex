defmodule Egapp.XMPP.Stanza do
  require Ecto.Query
  require Egapp.Constants, as: Const
  alias Egapp.XMPP.Element

  def iq(
        {%{"type" => "get"} = attrs,
         [{:xmlel, "query", %{"xmlns" => Const.xmlns_disco_items}, _data}]}, state
      ) do
    iq(attrs["id"], 'result', Element.query(xmlns: Const.xmlns_disco_items))
  end

  def iq(
        {%{"type" => "get"} = attrs,
         [{:xmlel, "query", %{"xmlns" => Const.xmlns_disco_info}, _data}]}, state
      ) do
    iq(
      attrs["id"],
      'result',
      Element.query(
        [xmlns: Const.xmlns_disco_info],
        [
          {:identity, [category: 'server', type: 'im'], []},
          {:feature, [var: Const.xmlns_disco_info], []},
          {:feature, [var: Const.xmlns_disco_items], []},
          {:feature, [var: Const.xmlns_ping], []},
          {:feature, [var: Const.xmlns_vcard], []},
          {:feature, [var: Const.xmlns_version], []},
          {:feature, [var: Const.xmlns_last], []},
        ]
      )
    )
  end

  def iq(
        {%{"type" => "get"} = attrs, [{:xmlel, "query", %{"xmlns" => Const.xmlns_roster}, _data}]}, state
      ) do
    roster =
      Ecto.Query.from(r in Egapp.Repo.Roster, where: r.user_id == ^state.client.id)
      |> Egapp.Repo.one()
      |> Egapp.Repo.preload(:users)

    items = Enum.map(roster.users, fn user ->
      {:item, [jid: String.to_charlist(user.username <> "@egapp.im"), subscription: 'both'], []}
    end)

    iq(
      attrs["id"],
      'result',
      Element.query(
        [xmlns: Const.xmlns_roster],
        items
      ),
      from: String.to_charlist(state.client.bare_jid)
    )
  end

  def iq(
        {%{"type" => "get"} = attrs,
         [{:xmlel, "query", %{"xmlns" => Const.xmlns_bytestreams}, _data}]}, state
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
      ),
      from: 'proxy.eu.jabber.org'
    )
  end

  def iq({%{"type" => "get"} = attrs, [{:xmlel, "query", %{"xmlns" => Const.xmlns_version}, _data}]}, state) do
    iq(
      attrs["id"],
      'result',
      Element.query(
        [xmlns: Const.xmlns_version],
        [
          {:name, ['egapp']},
          {:version, ['1.0.0']}
        ]
      ),
      from: attrs["to"]
    )
  end

  def iq({%{"type" => "get"} = attrs, [{:xmlel, "query", %{"xmlns" => Const.xmlns_last}, _data}]}, state) do
    iq(
      attrs["id"],
      'result',
      Element.query(
        [xmlns: Const.xmlns_last, seconds: 3650],
        []
      ),
      from: attrs["to"]
    )
  end

  def iq({%{"type" => "get"} = attrs, [{:xmlel, "time", %{"xmlns" => Const.xmlns_time}, _data}]}, state) do
    {:ok, now} = DateTime.now("Etc/UTC")
    iso_time = DateTime.to_iso8601(now)
    iq(
      attrs["id"],
      'result',
      {
        :time,
        [xmlns: Const.xmlns_time],
        [
          {:tzo, ['+00:00']},
          {:utc, [String.to_charlist(iso_time)]}
        ]
      },
      from: attrs["to"]
    )
  end

  def iq({%{"type" => "get"} = attrs, [{:xmlel, "vCard", _child_attrs, _data}]}, state) do
    iq(attrs["id"], 'result',
      {
        :vCard,
        [xmlns: 'vcard-temp'],
        []
      },
      from: attrs["to"]
    )
  end

  def iq({%{"type" => "get"} = attrs, [{:xmlel, "ping", _child_attrs, _data}]}, state) do
    iq(attrs["id"], 'result')
  end

  def iq({%{"type" => "set"} = attrs, [{:xmlel, "query", _child_attrs, _data}]}, state) do
    """
    <iq type='result' id='#{attrs["id"]}'/>
    """
  end

  def iq({%{"type" => "set"} = attrs, [{:xmlel, "bind", _child_attrs, _data}]}, state) do
    full_jid = '#{state.client.bare_jid}/#{state.client.resource}'
    iq(attrs["id"], 'result', Element.bind(full_jid))
  end

  def iq({%{"type" => "set"} = attrs, [{:xmlel, "session", _child_attrs, _data}]}, state) do
    iq(attrs["id"], 'result')
  end

  def iq(id, type, content \\ nil, attrs \\ []) do
    {
      :iq,
      [id: id, type: type, from: Keyword.get(attrs, :from) || 'egapp.im'],
      if content do
        [content]
      else
        []
      end
    }
  end

  def message({attrs, [{:xmlel, "composing", _child_attrs, _data}]}) do
  end

  def message({attrs, [{:xmlel, "paused", _child_attrs, _data}]}) do
  end

  def message({attrs, [{:xmlel, "active", _child_attrs, _data}]}) do
  end

  def message({attrs, [{:xmlel, "active", _child_attrs, _data}, body]}) do
    {:xmlel, "body", [], [xmlcdata: msg]} = body
    {
      :message,
      [
        from: String.to_charlist(attrs["from"]),
        id: String.to_charlist(attrs["id"]),
        to: String.to_charlist(attrs["to"]),
        type: 'chat',
        "xml:lang": 'en'
      ],
      [{:body, [String.to_charlist(msg)]}]
    }
  end

  def message({attrs, [{:xmlel, "body", [], [xmlcdata: msg]}]}) do
    {
      :message,
      [
        from: 'foo@egapp.im/4db06f06-1ea4-11dc-aca3-000bcd821bfb',
        id: '#{attrs["id"]}',
        to: 'gooz@egapp.im/4db06f06-1ea4-11dc-aca3-000bcd821bfb',
        type: 'chat',
        "xml:lang": 'en'
      ],
      [{:body, [String.to_charlist(msg)]}]
    }
  end

  def presence({attrs, foo}) do
    {
      :presence,
      [
        # id: attrs["id"],
        from: 'alice@egapp.im/android',
        to: 'foo@egapp.im'
      ],
      []
    }
  end
end
