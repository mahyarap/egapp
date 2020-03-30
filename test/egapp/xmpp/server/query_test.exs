defmodule Egapp.XMPP.Server.QueryTest do
  use ExUnit.Case, async: true

  require Ecto.Query
  require Egapp.Constants, as: Const

  alias Egapp.XMPP.Jid
  alias Egapp.Repo.{User, Roster}
  alias Egapp.XMPP.Server.Query

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Egapp.Repo)

    {:ok, state: %{to: self(), client: %{}}}
  end

  defp extract_resp([{_conn, resp}]), do: resp

  test "disco items", %{state: state} do
    attrs = %{"xmlns" => Const.xmlns_disco_items()}

    assert {:ok, result} = Query.query(attrs, nil, state)

    result =
      result
      |> extract_resp()
      |> :xmerl.export_simple_element(:xmerl_xml)
      |> IO.chardata_to_string()

    assert result =~ ~s(<query)
    assert result =~ ~s(xmlns="#{Const.xmlns_disco_items()}")
    assert result =~ ~s(<item)
  end

  test "disco info for server", %{state: state} do
    attrs = %{"xmlns" => Const.xmlns_disco_info()}

    assert {:ok, result} = Query.query(attrs, nil, state)

    result =
      result
      |> extract_resp()
      |> :xmerl.export_simple_element(:xmerl_xml)
      |> IO.chardata_to_string()

    assert result =~ ~s(<query)
    assert result =~ ~s(xmlns="#{Const.xmlns_disco_info()}")
    assert result =~ ~s(<identity)
    assert result =~ ~s(category="server")
    assert result =~ ~s(type="im")
    assert result =~ ~s(<feature)
  end

  test "getting roster when contact exists", %{state: state} do
    attrs = %{"xmlns" => Const.xmlns_roster()}

    user1 = Egapp.Repo.insert!(%User{username: "foo"})
    user2 = Egapp.Repo.insert!(%User{username: "bar"})

    %Roster{user: user1, users: [user2]}
    |> Egapp.Repo.insert!()

    state = put_in(state, [:client, :id], user1.id)

    assert {:ok, result} = Query.query(attrs, [], state)

    result =
      result
      |> extract_resp()
      |> :xmerl.export_simple_element(:xmerl_xml)
      |> IO.chardata_to_string()

    assert result =~ ~s(<query)
    assert result =~ ~s(xmlns="#{Const.xmlns_roster()}")
    assert result =~ ~s(<item)

    jid = %Jid{localpart: user2.username, domainpart: Egapp.XMPP.Server.address()}
    assert result =~ ~s(jid="#{Jid.bare_jid(jid)}")
  end

  test "getting roster with no contacts", %{state: state} do
    attrs = %{"xmlns" => Const.xmlns_roster()}

    user1 = Egapp.Repo.insert!(%User{username: "foo"})

    %Roster{user: user1, users: []}
    |> Egapp.Repo.insert!()

    state = put_in(state, [:client, :id], user1.id)
    assert {:ok, result} = Query.query(attrs, [], state)

    result =
      result
      |> extract_resp
      |> :xmerl.export_simple_element(:xmerl_xml)
      |> IO.chardata_to_string()

    assert result =~ ~s(<query)
    assert result =~ ~s(xmlns="#{Const.xmlns_roster()}")
    refute result =~ ~s(<item)
  end

  test "adding contact to roster" do
    jid = Jid.parse("bar@egapp.im")
    attrs = %{"xmlns" => Const.xmlns_roster()}
    data = {"item", %{"jid" => Jid.bare_jid(jid)}, []}

    user1 = Egapp.Repo.insert!(%User{username: "foo"})
    Egapp.Repo.insert!(%User{username: "bar"})

    %Roster{user: user1}
    |> Egapp.Repo.insert!()

    state = %{client: %{id: user1.id}}

    query =
      Ecto.Query.from(r in Egapp.Repo.Roster,
        where: r.user_id == ^user1.id,
        preload: :users
      )

    roster = query |> Egapp.Repo.one()
    assert [] = roster.users

    result = Query.query(attrs, data, state)
    assert [] = result

    roster = query |> Egapp.Repo.one()
    assert [%Egapp.Repo.User{username: "bar"}] = roster.users
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
    assert [%Egapp.Repo.User{username: "bar"}] = roster.users

    result = Query.query(attrs, data, state)
    assert [] = result

    roster = query |> Egapp.Repo.one()
    assert nil == roster
  end

  test "passing unknown xml namespace", %{state: state} do
    attrs = %{"xmlns" => "foo"}

    assert {:error, result} = Query.query(attrs, nil, state)

    result =
      result
      |> extract_resp()
      |> :xmerl.export_simple_element(:xmerl_xml)
      |> IO.chardata_to_string()

    assert result =~ "<error"
    assert result =~ "<service-unavailable"
  end
end
