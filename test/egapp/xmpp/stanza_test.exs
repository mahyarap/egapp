defmodule Egapp.XMPP.StanzaTest do
  use ExUnit.Case, async: true

  require Egapp.Constants, as: Const

  alias Egapp.Utils
  alias Egapp.XMPP.Jid
  alias Egapp.XMPP.Stanza
  alias Egapp.JidConnRegistry

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Egapp.Repo)
    start_supervised!(JidConnRegistry)

    state = %{
      client: %{},
      id: Utils.generate_id() |> Integer.to_string()
    }

    {:ok, state: state}
  end

  test "returns correct resource binding", %{state: state} do
    attrs = %{"type" => "set", "id" => state.id}
    child = {"bind", %{"xmlns" => Const.xmlns_bind()}, []}

    jid = %Jid{localpart: "foo", domainpart: "bar", resourcepart: "123"}
    state = put_in(state, [:client, :jid], jid)

    assert {:ok, resp} = Stanza.iq(attrs, child, state)
    resp = IO.chardata_to_string(resp)

    assert resp =~ ~s(<iq)
    assert resp =~ ~s(from="egapp.im")
    assert resp =~ state.id
    assert resp =~ ~s(type="result")
    assert resp =~ ~s(bind)
    assert resp =~ ~s(xmlns="#{Const.xmlns_bind()}")
    assert resp =~ ~s(<jid>)
    assert resp =~ ~s(foo@bar/123)
  end

  test "returns correct session estabslishment", %{state: state} do
    attrs = %{"type" => "set", "id" => state.id}
    child = {"session", %{"xmlns" => Const.xmlns_bind()}, []}

    assert {:ok, resp} = Stanza.iq(attrs, child, state)
    resp = IO.chardata_to_string(resp)

    assert resp =~ ~s(<iq)
    assert resp =~ ~s(from="egapp.im")
    assert resp =~ state.id
    assert resp =~ ~s(type="result")
  end

  test "returns correct disco items", %{state: state} do
    attrs = %{"type" => "get", "id" => state.id}
    child = {"query", %{"xmlns" => Const.xmlns_disco_items()}, []}
    state = Map.put(state, :cats, [Egapp.XMPP.Server, Egapp.XMPP.Conference])
    assert {:ok, resp} = Stanza.iq(attrs, child, state)
    resp = IO.chardata_to_string(resp)

    assert resp =~ ~s(<iq)
    assert resp =~ ~s(from="egapp.im")
    assert resp =~ state.id
    assert resp =~ ~s(type="result")
    assert resp =~ ~s(query)
    assert resp =~ ~s(xmlns="#{Const.xmlns_disco_items()}")
  end

  test "returns correct disco info for server category", %{state: state} do
    attrs = %{"type" => "get", "id" => state.id, "to" => "egapp.im"}
    child = {"query", %{"xmlns" => Const.xmlns_disco_info()}, []}
    state = Map.put(state, :cats, [Egapp.XMPP.Server, Egapp.XMPP.Conference])
    assert {:ok, resp} = Stanza.iq(attrs, child, state)
    resp = IO.chardata_to_string(resp)

    assert resp =~ ~s(<iq)
    assert resp =~ ~s(from="egapp.im")
    assert resp =~ state.id
    assert resp =~ ~s(type="result")
    assert resp =~ ~s(query)
    assert resp =~ ~s(xmlns=") <> Const.xmlns_disco_info() <> ~s(")
    assert resp =~ ~s(<identity)
    assert resp =~ ~s(type="im")
    assert resp =~ ~s(category="server")
    assert resp =~ ~s(feature var="#{Const.xmlns_disco_items()}")
    assert resp =~ ~s(feature var="#{Const.xmlns_disco_info()}")
    assert resp =~ ~s(feature var="#{Const.xmlns_ping()}")
    assert resp =~ ~s(feature var="#{Const.xmlns_vcard()}")
    assert resp =~ ~s(feature var="#{Const.xmlns_version()}")
    assert resp =~ ~s(feature var="#{Const.xmlns_last()}")
  end

  test "returns correct disco info for conference category", %{state: state} do
    attrs = %{"type" => "get", "id" => state.id, "to" => "conference.egapp.im"}
    child = {"query", %{"xmlns" => Const.xmlns_disco_info()}, []}
    state = Map.put(state, :cats, [Egapp.XMPP.Server, Egapp.XMPP.Conference])
    assert {:ok, resp} = Stanza.iq(attrs, child, state)
    resp = IO.chardata_to_string(resp)

    assert resp =~ ~s(<iq)
    assert resp =~ ~s(from="conference.egapp.im")
    assert resp =~ state.id
    assert resp =~ ~s(type="result")
    assert resp =~ ~s(query)
    assert resp =~ ~s(xmlns=") <> Const.xmlns_disco_info() <> ~s(")
    assert resp =~ ~s(<identity)
    assert resp =~ ~s(type="text")
    assert resp =~ ~s(category="conference")
    assert resp =~ ~s(feature var="#{Const.xmlns_disco_items()}")
    assert resp =~ ~s(feature var="#{Const.xmlns_disco_info()}")
    assert resp =~ ~s(feature var="#{Const.xmlns_vcard()}")
  end

  test "returns correct vcard", %{state: state} do
    attrs = %{"type" => "get", "id" => state.id}
    child = {"vCard", %{"xmlns" => Const.xmlns_vcard()}, []}
    assert {:ok, resp} = Stanza.iq(attrs, child, state)
    resp = IO.chardata_to_string(resp)

    assert resp =~ ~s(<iq)
    assert resp =~ ~s(from="egapp.im")
    assert resp =~ state.id
    assert resp =~ ~s(type="result")
    assert resp =~ ~s(vCard)
    assert resp =~ ~s(xmlns="#{Const.xmlns_vcard()}")
  end

  test "returns correct roster", %{state: state} do
    attrs = %{"type" => "get", "id" => state.id}
    child = {"query", %{"xmlns" => Const.xmlns_roster()}, []}

    user = Egapp.Repo.insert!(%Egapp.Repo.User{username: "foo"})
    contact = Egapp.Repo.insert!(%Egapp.Repo.User{username: "bar"})
    Egapp.Repo.insert!(%Egapp.Repo.Roster{user: user, users: [contact]})

    state = put_in(state, [:client, :id], user.id)
    assert {:ok, resp} = Stanza.iq(attrs, child, state)
    resp = IO.chardata_to_string(resp)

    assert resp =~ ~s(<iq)
    assert resp =~ ~s(from="egapp.im")
    assert resp =~ state.id
    assert resp =~ ~s(type="result")
    assert resp =~ ~s(<query)
    assert resp =~ ~s(xmlns="#{Const.xmlns_roster()}")
    assert resp =~ ~s(<item)
    assert resp =~ ~s(jid="bar@egapp.im")
  end

  test "returns correct time", %{state: state} do
    attrs = %{"type" => "get", "id" => state.id}
    child = {"time", %{"xmlns" => Const.xmlns_time()}, []}
    state = put_in(state, [:client, :id], 1)
    assert {:ok, resp} = Stanza.iq(attrs, child, state)
    resp = IO.chardata_to_string(resp)

    assert resp =~ ~s(<iq)
    assert resp =~ ~s(from="egapp.im")
    assert resp =~ state.id
    assert resp =~ ~s(type="result")
    assert resp =~ ~s(<time)
    assert resp =~ ~s(xmlns="#{Const.xmlns_time()}")
  end

  test "returns correct version", %{state: state} do
    attrs = %{"type" => "get", "id" => state.id}
    child = {"query", %{"xmlns" => Const.xmlns_version()}, []}
    state = put_in(state, [:client, :id], 1)
    assert {:ok, resp} = Stanza.iq(attrs, child, state)
    resp = IO.chardata_to_string(resp)

    assert resp =~ ~s(<iq)
    assert resp =~ ~s(from="egapp.im")
    assert resp =~ state.id
    assert resp =~ ~s(type="result")
    assert resp =~ ~s(<query)
    assert resp =~ ~s(xmlns="#{Const.xmlns_version()}")
    assert resp =~ ~s(<name)
    assert resp =~ ~s(<version)
  end

  @tag :skip
  test "returns correct last seen", %{state: state} do
    attrs = %{"type" => "get", "id" => state.id}
    child = {"query", %{"xmlns" => Const.xmlns_last()}, []}
    state = put_in(state, [:client, :id], 1)
    assert {:ok, resp} = Stanza.iq(attrs, child, state)
    resp = IO.chardata_to_string(resp)

    assert resp =~ ~s(<iq)
    assert resp =~ ~s(from="egapp.im")
    assert resp =~ state.id
    assert resp =~ ~s(type="result")
    assert resp =~ ~s(<query)
    assert resp =~ ~s(xmlns="#{Const.xmlns_version()}")
    assert resp =~ ~s(<name)
    assert resp =~ ~s(<version)
  end

  test "returns correct message", %{state: state} do
    attrs = %{
      "type" => "chat",
      "id" => state.id,
      "to" => "baz@buf"
    }

    child = [{"active", %{"xmlns" => Const.xmlns_version()}, []}]
    jid = %Jid{localpart: "foo", domainpart: "bar", resourcepart: "123"}
    state = put_in(state, [:client, :jid], jid)
    JidConnRegistry.put(Jid.bare_jid(jid), [])

    assert {:ok, {to, resp}} = Stanza.message(attrs, child, state)
    resp = IO.chardata_to_string(resp)

    assert resp =~ ~s(<message)
    assert resp =~ ~s(from="foo@bar/123")
    assert resp =~ state.id
    assert resp =~ ~s(type="chat")
    assert resp =~ ~s(<active)
    assert resp =~ ~s(xmlns="#{Const.xmlns_chatstates()}")
  end
end
