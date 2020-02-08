defmodule Egapp.XMPP.Server.Element do
  require Ecto.Query
  require Egapp.Constants, as: Const

  alias Egapp.XMPP.Jid

  def query(%{"xmlns" => Const.xmlns_disco_items()}, _data, _state) do
    query_template(
      [xmlns: Const.xmlns_disco_items()],
      [
        {:item, [jid: "conference.egapp.im"], []}
      ]
    )
  end

  def query(%{"xmlns" => Const.xmlns_disco_info()}, _data, state) do
    content =
      state.cats
      |> Enum.filter(fn cat -> cat.address() == "egapp.im" end)
      |> Enum.map(fn cat -> [cat.identity() | cat.features()] end)
      |> hd()

    query_template([xmlns: Const.xmlns_disco_info()], content)
  end

  def query(%{"xmlns" => Const.xmlns_roster()}, _data, state) do
    roster =
      Ecto.Query.from(r in Egapp.Repo.Roster, where: r.user_id == ^state.client.id)
      |> Egapp.Repo.one()
      |> Egapp.Repo.preload(:users)

    items =
      Enum.map(roster.users, fn user ->
        {
          :item,
          [jid: String.to_charlist(user.username <> "@egapp.im"), subscription: 'both'],
          []
        }
      end)

    query_template([xmlns: Const.xmlns_roster()], items)
  end

  def query(%{"xmlns" => Const.xmlns_bytestreams()}, _data, _state) do
    content = [
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

    query_template([xmlns: Const.xmlns_disco_info()], content)
  end

  def query(%{"xmlns" => Const.xmlns_version()}, _data, _state) do
    content = [
      {:name, ['egapp']},
      {:version, ['1.0.0']}
    ]

    query_template([xmlns: Const.xmlns_version()], content)
  end

  def query(%{"xmlns" => Const.xmlns_last()}, _data, _state) do
    query_template([xmlns: Const.xmlns_last()], [])
  end

  def query_template(attrs, content), do: {:query, attrs, content}

  @doc """
  RFC6120 7.4
  RFC6120 7.6.1
  """
  def bind(_attrs, _data, state) do
    full_jid = Jid.full_jid(state.client.jid) |> String.to_charlist()

    {
      :bind,
      [xmlns: Const.xmlns_bind()],
      [{:jid, [], [full_jid]}]
    }
  end

  def bind() do
    {
      :bind,
      [xmlns: Const.xmlns_bind()],
      []
    }
  end

  def session(_attrs, _data, _state), do: []

  def session do
    {
      :session,
      [xmlns: Const.xmlns_session()],
      []
    }
  end

  def vcard(_attrs, _data, _state) do
    {
      :vCard,
      [xmlns: Const.xmlns_vcard()],
      []
    }
  end

  def ping(_attrs, _data, _state) do
    {
      :ping,
      [xmlns: Const.xmlns_ping()],
      []
    }
  end

  def time(_attrs, _data, _state) do
    {:ok, now} = DateTime.now("Etc/UTC")
    iso_time = DateTime.to_iso8601(now)

    {
      :time,
      [xmlns: Const.xmlns_time()],
      [
        {:tzo, ['+00:00']},
        {:utc, [String.to_charlist(iso_time)]}
      ]
    }
  end
end
