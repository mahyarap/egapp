defmodule Egapp.XMPP.StanzaTest do
  use ExUnit.Case, async: true
  require Egapp.Constants, as: Const
  alias Egapp.XMPP.Stanza

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Egapp.Repo)
    state = %{
      client: %{}
    }

    {:ok, state: state}
  end

  test "returns correct resource binding", %{state: state} do
    id = "#{Enum.random(10_000_000..99_999_999)}"
    attrs = %{"type" => "set", "id" => id}
    child = {"bind", %{"xmlns" => Const.xmlns_bind()}, []}

    state =
      state
      |> put_in([:client, :bare_jid], "foo@bar")
      |> put_in([:client, :resource], "123")

    assert {:ok, resp} = Stanza.iq(attrs, child, state)
    resp = IO.chardata_to_string(resp)

    assert resp =~ ~s(<iq)
    assert resp =~ ~s(from="egapp.im")
    assert resp =~ id
    assert resp =~ ~s(type="result")
    assert resp =~ ~s(bind)
    assert resp =~ ~s(xmlns=") <> Const.xmlns_bind() <> ~s(")
    assert resp =~ ~s(<jid>)
    assert resp =~ ~s(foo@bar/123)
  end

  test "returns correct session estabslishment", %{state: state} do
    id = "#{Enum.random(10_000_000..99_999_999)}"
    attrs = %{"type" => "set", "id" => id}
    child = {"session", %{"xmlns" => Const.xmlns_bind()}, []}

    assert {:ok, resp} = Stanza.iq(attrs, child, state)
    resp = IO.chardata_to_string(resp)

    assert resp =~ ~s(<iq)
    assert resp =~ ~s(from="egapp.im")
    assert resp =~ id
    assert resp =~ ~s(type="result")
  end

  test "returns correct disco items", %{state: state} do
    id = "#{Enum.random(10_000_000..99_999_999)}"
    attrs = %{"type" => "get", "id" => id}
    child = {"query", %{"xmlns" => Const.xmlns_disco_items()}, []}
    assert {:ok, resp} = Stanza.iq(attrs, child, state)
    resp = IO.chardata_to_string(resp)

    assert resp =~ ~s(<iq)
    assert resp =~ ~s(from="egapp.im")
    assert resp =~ id
    assert resp =~ ~s(type="result")
    assert resp =~ ~s(query)
    assert resp =~ ~s(xmlns=") <> Const.xmlns_disco_items() <> ~s(")
  end

  test "returns correct disco info", %{state: state} do
    id = "#{Enum.random(10_000_000..99_999_999)}"
    attrs = %{"type" => "get", "id" => id}
    child = {"query", %{"xmlns" => Const.xmlns_disco_info()}, []}
    assert {:ok, resp} = Stanza.iq(attrs, child, state)
    resp = IO.chardata_to_string(resp)

    assert resp =~ ~s(<iq)
    assert resp =~ ~s(from="egapp.im")
    assert resp =~ id
    assert resp =~ ~s(type="result")
    assert resp =~ ~s(query)
    assert resp =~ ~s(xmlns=") <> Const.xmlns_disco_info() <> ~s(")
    assert resp =~ ~s(<identity)
    assert resp =~ ~s(type="im")
    assert resp =~ ~s(category="server")
    assert resp =~ ~s(feature var=") <> Const.xmlns_disco_items() <> ~s(")
    assert resp =~ ~s(feature var=") <> Const.xmlns_disco_info() <> ~s(")
    assert resp =~ ~s(feature var=") <> Const.xmlns_ping() <> ~s(")
    assert resp =~ ~s(feature var=") <> Const.xmlns_vcard() <> ~s(")
    assert resp =~ ~s(feature var=") <> Const.xmlns_version() <> ~s(")
    assert resp =~ ~s(feature var=") <> Const.xmlns_last() <> ~s(")
  end

  test "returns correct vcard", %{state: state} do
    id = "#{Enum.random(10_000_000..99_999_999)}"
    attrs = %{"type" => "get", "id" => id}
    child = {"vCard", %{"xmlns" => Const.xmlns_vcard()}, []}
    assert {:ok, resp} = Stanza.iq(attrs, child, state)
    resp = IO.chardata_to_string(resp)

    assert resp =~ ~s(<iq)
    assert resp =~ ~s(from="egapp.im")
    assert resp =~ id
    assert resp =~ ~s(type="result")
    assert resp =~ ~s(vCard)
    assert resp =~ ~s(xmlns=") <> Const.xmlns_vcard() <> ~s(")
  end

  test "returns correct roster", %{state: state} do
    id = "#{Enum.random(10_000_000..99_999_999)}"
    attrs = %{"type" => "get", "id" => id}
    child = {"query", %{"xmlns" => Const.xmlns_roster()}, []}

    user = Egapp.Repo.insert!(%Egapp.Repo.User{username: "foo"})
    contact = Egapp.Repo.insert!(%Egapp.Repo.User{username: "bar"})
    Egapp.Repo.insert!(%Egapp.Repo.Roster{user: user, users: [contact]})

    state = put_in(state, [:client, :id], user.id)
    assert {:ok, resp} = Stanza.iq(attrs, child, state)
    resp = IO.chardata_to_string(resp)

    assert resp =~ ~s(<iq)
    assert resp =~ ~s(from="egapp.im")
    assert resp =~ id
    assert resp =~ ~s(type="result")
    assert resp =~ ~s(<query)
    assert resp =~ ~s(xmlns=") <> Const.xmlns_roster() <> ~s(")
    assert resp =~ ~s(<item)
    assert resp =~ ~s(jid="bar@egapp.im")
  end

  test "returns correct time", %{state: state} do
    id = "#{Enum.random(10_000_000..99_999_999)}"
    attrs = %{"type" => "get", "id" => id}
    child = {"time", %{"xmlns" => Const.xmlns_time()}, []}
    state = put_in(state, [:client, :id], 1)
    assert {:ok, resp} = Stanza.iq(attrs, child, state)
    resp = IO.chardata_to_string(resp)

    assert resp =~ ~s(<iq)
    assert resp =~ ~s(from="egapp.im")
    assert resp =~ id
    assert resp =~ ~s(type="result")
    assert resp =~ ~s(<time)
    assert resp =~ ~s(xmlns=") <> Const.xmlns_time() <> ~s(")
  end

  test "returns correct version", %{state: state} do
    id = "#{Enum.random(10_000_000..99_999_999)}"
    attrs = %{"type" => "get", "id" => id}
    child = {"query", %{"xmlns" => Const.xmlns_version()}, []}
    state = put_in(state, [:client, :id], 1)
    assert {:ok, resp} = Stanza.iq(attrs, child, state)
    resp = IO.chardata_to_string(resp)

    assert resp =~ ~s(<iq)
    assert resp =~ ~s(from="egapp.im")
    assert resp =~ id
    assert resp =~ ~s(type="result")
    assert resp =~ ~s(<query)
    assert resp =~ ~s(xmlns=") <> Const.xmlns_version() <> ~s(")
    assert resp =~ ~s(<name)
    assert resp =~ ~s(<version)
  end

  @tag :skip
  test "returns correct last seen", %{state: state} do
    id = "#{Enum.random(10_000_000..99_999_999)}"
    attrs = %{"type" => "get", "id" => id}
    child = {"query", %{"xmlns" => Const.xmlns_last()}, []}
    state = put_in(state, [:client, :id], 1)
    assert {:ok, resp} = Stanza.iq(attrs, child, state)
    resp = IO.chardata_to_string(resp)

    assert resp =~ ~s(<iq)
    assert resp =~ ~s(from="egapp.im")
    assert resp =~ id
    assert resp =~ ~s(type="result")
    assert resp =~ ~s(<query)
    assert resp =~ ~s(xmlns=") <> Const.xmlns_version() <> ~s(")
    assert resp =~ ~s(<name)
    assert resp =~ ~s(<version)
  end
end
