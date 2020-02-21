defmodule Egapp.XMPP.Server.ElementTest do
  use ExUnit.Case, async: true

  require Ecto.Query
  require Egapp.Constants, as: Const

  alias Egapp.XMPP.Jid
  alias Egapp.Repo.{User, Roster}
  alias Egapp.XMPP.Server.Element

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Egapp.Repo)
  end

  test "disco items" do
    attrs = %{"xmlns" => Const.xmlns_disco_items()}
    state = %{cats: [Egapp.XMPP.Server, Egapp.XMPP.Conference]}

    result =
      Element.query(attrs, nil, state)
      |> :xmerl.export_simple_element(:xmerl_xml)
      |> IO.chardata_to_string()
    
    assert result =~ ~s(<query)
    assert result =~ ~s(xmlns="#{Const.xmlns_disco_items()}")
    assert result =~ ~s(<item)
  end

  test "disco info for server" do
    attrs = %{"xmlns" => Const.xmlns_disco_info()}
    state = %{cats: [Egapp.XMPP.Server]}

    result =
      Element.query(attrs, nil, state)
      |> :xmerl.export_simple_element(:xmerl_xml)
      |> IO.chardata_to_string()

    assert result =~ ~s(<query)
    assert result =~ ~s(xmlns="#{Const.xmlns_disco_info()}")
    assert result =~ ~s(<identity)
    assert result =~ ~s(category="server")
    assert result =~ ~s(type="im")
    assert result =~ ~s(<feature)
  end

  test "getting roster" do
    attrs = %{"xmlns" => Const.xmlns_roster()}

    user1 = Egapp.Repo.insert!(%User{username: "foo"})
    user2 = Egapp.Repo.insert!(%User{username: "bar"})

    %Roster{user: user1, users: [user2]}
    |> Egapp.Repo.insert!()

    state = %{client: %{id: user1.id}}

    result =
      Element.query(attrs, [], state)
      |> :xmerl.export_simple_element(:xmerl_xml)
      |> IO.chardata_to_string()

    assert result =~ ~s(<query)
    assert result =~ ~s(xmlns="#{Const.xmlns_roster()}")
    assert result =~ ~s(<item)

    jid = %Jid{localpart: user2.username, domainpart: Egapp.XMPP.Server.address()}
    assert result =~ ~s(jid="#{Jid.bare_jid(jid)}")
  end

  test "removing contact from roster" do
    jid = Jid.parse("bar@egapp.im")
    attrs = %{"xmlns" => Const.xmlns_roster()}
    data = {"item", %{"subscription" => "remove", "jid" => Jid.bare_jid(jid)}, []}

    user1 = Egapp.Repo.insert!(%User{username: "foo"})
    user2 = Egapp.Repo.insert!(%User{username: "bar"})

    %Roster{user: user1, users: [user2]}
    |> Egapp.Repo.insert!()

    state = %{client: %{id: user1.id}}

    query =
      Ecto.Query.from(r in Egapp.Repo.Roster,
        join: u in assoc(r, :users),
        where: r.user_id == ^user1.id and u.username == ^jid.localpart,
        preload: :users
      )

    roster = query |> Egapp.Repo.one()
    assert [%Egapp.Repo.User{}] = roster.users

    result = Element.query(attrs, data, state)
    assert [] = result

    roster = query |> Egapp.Repo.one()
    assert nil == roster
  end
end
