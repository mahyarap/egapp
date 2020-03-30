defmodule Egapp.XMPP.Server.Query do
  require Ecto.Query
  require Egapp.Constants, as: Const

  alias Egapp.Config
  alias Egapp.XMPP.Jid
  alias Egapp.XMPP.Server
  alias Egapp.XMPP.Element

  def query(%{"xmlns" => Const.xmlns_disco_items()}, _data, state) do
    content =
      Kernel.||(Map.get(state, :services), Config.get(:services))
      |> Enum.filter(&Kernel.!=(&1, Egapp.XMPP.Server))
      |> Enum.map(fn cat -> Element.item([jid: cat.address()], []) end)

    resp = query_template([xmlns: Const.xmlns_disco_items()], content)
    {:ok, [{state.to, resp}]}
  end

  def query(%{"xmlns" => Const.xmlns_disco_info()}, _data, state) do
    content = [Server.identity() | Server.features()]
    resp = query_template([xmlns: Const.xmlns_disco_info()], content)
    {:ok, [{state.to, resp}]}
  end

  @doc """
  Roster get

  RFC6121 2.1.3
  """
  def query(%{"xmlns" => Const.xmlns_roster()}, [], state) do
    roster =
      Ecto.Query.from(r in Egapp.Repo.Roster, where: r.user_id == ^state.client.id)
      |> Egapp.Repo.one()
      |> Egapp.Repo.preload(:users)

    items =
      Enum.map(roster.users, fn user ->
        jid = %Jid{
          localpart: user.username,
          domainpart: Config.get(:domain_name)
        }

        attrs = [
          jid: Jid.bare_jid(jid),
          subscription: 'both'
        ]

        Element.item(attrs, [])
      end)

    resp = query_template([xmlns: Const.xmlns_roster()], items)
    {:ok, [{state.to, resp}]}
  end

  def query(
        %{"xmlns" => Const.xmlns_roster()},
        {"item", %{"subscription" => "remove", "jid" => jid}, _child_data},
        state
      ) do
    jid = Jid.partial_parse(jid)

    roster =
      Ecto.Query.from(r in Egapp.Repo.Roster,
        join: u in assoc(r, :users),
        where: r.user_id == ^state.client.id and u.username == ^jid.localpart,
        preload: [users: u]
      )
      |> Egapp.Repo.one()

    user = hd(roster.users)

    if roster do
      Ecto.Query.from(ur in "users_rosters",
        where: ur.user_id == ^user.id and ur.roster_id == ^roster.id
      )
      |> Egapp.Repo.delete_all()

      []
    end
  end

  def query(%{"xmlns" => Const.xmlns_roster()}, {"item", %{"jid" => jid}, _child_data}, state) do
    jid = Jid.partial_parse(jid)

    roster =
      Ecto.Query.from(r in Egapp.Repo.Roster,
        where: r.user_id == ^state.client.id,
        preload: [:users]
      )
      |> Egapp.Repo.one()

    user =
      Ecto.Query.from(u in Egapp.Repo.User,
        where: u.username == ^jid.localpart
      )
      |> Egapp.Repo.one()

    if roster != nil and user != nil do
      Egapp.Repo.insert_all("users_rosters", [%{user_id: user.id, roster_id: roster.id}])
      []
    end
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

  def query(%{"xmlns" => Const.xmlns_version()}, _data, state) do
    content = [
      {:name, ['egapp']},
      {:version, ['1.0.0']}
    ]

    resp = query_template([xmlns: Const.xmlns_version()], content)
    {:ok, [{state.to, resp}]}
  end

  def query(%{"xmlns" => Const.xmlns_last()}, _data, _state) do
    query_template([xmlns: Const.xmlns_last()], [])
  end

  def query(%{"xmlns" => _xmlns}, _data, state) do
    {:error, [{state.to, Egapp.XMPP.Element.service_unavailable_error(:cancel)}]}
  end

  def query_template(attrs, content), do: {:query, attrs, content}
end
