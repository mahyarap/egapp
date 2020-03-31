defmodule Egapp.XMPP.Server.StanzaTest do
  use ExUnit.Case, async: true

  require Egapp.Constants, as: Const

  alias Egapp.XMPP.Jid
  alias Egapp.XMPP.Server.Stanza

  setup do
    state = %{
      to: self(),
      mod: Kernel,
      client: %{}
    }

    {:ok, %{state: state}}
  end

  describe "iq get" do
    setup do
      [attrs: %{"type" => "get"}]
    end

    test "with correct query", %{state: state, attrs: attrs} do
      data = {"query", %{"xmlns" => Const.xmlns_disco_items()}, []}
      assert {:ok, resp} = Stanza.iq(attrs, data, state)

      resp = chardata_to_string(resp)
      assert resp =~ ~s(<iq)
      assert resp =~ ~s(<query)
    end

    test "with invalid namespace query", %{state: state, attrs: attrs} do
      data = {"query", %{"xmlns" => "foo"}, []}
      assert {:ok, resp} = Stanza.iq(attrs, data, state)

      resp = chardata_to_string(resp)
      assert resp =~ ~s(<error)
    end

    test "with vcard", %{state: state, attrs: attrs} do
      data = {"vCard", %{"xmlns" => Const.xmlns_vcard()}, []}
      assert {:ok, resp} = Stanza.iq(attrs, data, state)

      resp = chardata_to_string(resp)
      assert resp =~ ~s(<iq)
      assert resp =~ ~s(<vCard)
    end

    test "with time", %{state: state, attrs: attrs} do
      data = {"time", %{"xmlns" => Const.xmlns_time()}, []}
      assert {:ok, resp} = Stanza.iq(attrs, data, state)

      resp = chardata_to_string(resp)
      assert resp =~ ~s(<iq)
      assert resp =~ ~s(<time)
    end

    test "with ping", %{state: state, attrs: attrs} do
      data = {"ping", %{"xmlns" => Const.xmlns_ping()}, []}
      assert {:ok, resp} = Stanza.iq(attrs, data, state)

      resp = chardata_to_string(resp)
      assert resp =~ ~s(<iq)
      assert resp =~ ~s(<ping)
    end
  end

  describe "iq set" do
    setup do
      [attrs: %{"type" => "set"}]
    end

    @tag skip: "needs a stub"
    test "with correct query", %{state: state, attrs: attrs} do
      data = {
        "query",
        %{"xmlns" => Const.xmlns_roster()},
        [{:xmlel, "item", %{"subscription" => "remove", "jid" => "foo@bar"}, []}]
      }

      state = put_in(state, [:client, :id], 1)
      assert {:ok, resp} = Stanza.iq(attrs, data, state)

      resp = chardata_to_string(resp)
      assert resp =~ ~s(<iq)
      assert resp =~ ~s(<ping)
    end

    test "with empty data query", %{state: state, attrs: attrs} do
      data = {"query", %{"xmlns" => Const.xmlns_roster()}, []}
      assert {:ok, resp} = Stanza.iq(attrs, data, state)

      resp = chardata_to_string(resp)
      assert resp =~ ~s(<iq)
      assert resp =~ ~s(<ping)
    end

    test "with invalid namespace query", %{state: state, attrs: attrs} do
      data = {
        "query",
        %{"xmlns" => "foo"},
        [{:xmlel, "item", %{"subscription" => "remove", "jid" => "foo@bar"}, []}]
      }

      assert {:ok, resp} = Stanza.iq(attrs, data, state)

      resp = chardata_to_string(resp)
      assert resp =~ ~s(<error)
    end

    test "with bind", %{state: state, attrs: attrs} do
      data = {"bind", %{"xmlns" => Const.xmlns_bind()}, []}

      state =
        put_in(state, [:client, :jid], %Jid{
          localpart: "foo",
          domainpart: "bar",
          resourcepart: "123"
        })

      assert {:ok, resp} = Stanza.iq(attrs, data, state)

      resp = chardata_to_string(resp)
      assert resp =~ ~s(<iq)
      assert resp =~ ~s(<bind)
    end

    test "with session", %{state: state, attrs: attrs} do
      data = {"session", %{"xmlns" => Const.xmlns_session()}, []}
      assert {:ok, resp} = Stanza.iq(attrs, data, state)

      resp = chardata_to_string(resp)
      assert resp =~ ~s(<iq)
    end
  end

  test "iq with invalid type", %{state: state} do
    attrs = %{"type" => "foo"}
    assert {:error, resp} = Stanza.iq(attrs, %{}, state)

    resp = chardata_to_string(resp)
    assert resp =~ ~s(<stream:error)
    assert resp =~ ~s(<invalid-xml)
  end

  test "iq with invalid child element", %{state: state} do
    attrs = %{"type" => "get"}
    data = {"foo", %{"xmlns" => Const.xmlns_bind()}, []}
    assert {:ok, resp} = Stanza.iq(attrs, data, state)

    resp = chardata_to_string(resp)
    assert resp =~ ~s(<iq)
    assert resp =~ ~s(<error)
    assert resp =~ ~s(<bad-request)
  end

  defp extract_resp([{_conn, resp}]), do: resp

  defp chardata_to_string(chardata), do: chardata |> extract_resp() |> IO.chardata_to_string()
end
