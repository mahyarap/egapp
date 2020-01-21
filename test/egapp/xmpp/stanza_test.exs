defmodule Egapp.XMPP.StanzaTest do
  use ExUnit.Case, async: true
  require Egapp.Constants, as: Const
  alias Egapp.XMPP.Stanza

  setup do
    state = %{
      client: %{}
    }

    {:ok, state: state}
  end

  test "returns correct bind", %{state: state} do
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

  test "returns correct session", %{state: state} do
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

  @tag :skip
  test "returns correct roster", %{state: state} do
    id = "#{Enum.random(10_000_000..99_999_999)}"
    attrs = %{"type" => "get", "id" => id}
    child = {"query", %{"xmlns" => Const.xmlns_roster()}, []}
    state = put_in(state, [:client, :id], 1)
    assert {:ok, resp} = Stanza.iq(attrs, child, state)
    resp = IO.chardata_to_string(resp)

    assert resp =~ ~s(<iq)
    assert resp =~ ~s(from="egapp.im")
    assert resp =~ id
    assert resp =~ ~s(type="result")
    assert resp =~ ~s(vCard)
    assert resp =~ ~s(xmlns=") <> Const.xmlns_vcard() <> ~s(")
  end
end