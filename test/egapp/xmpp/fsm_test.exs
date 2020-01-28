defmodule Egapp.XMPP.FSMTest do
  use ExUnit.Case, async: true

  require Egapp.Constants, as: Const

  setup do
    child_spec = %{
      id: Egapp.XMPP.FSM,
      start: {Egapp.XMPP.FSM, :start_link, [[mod: Kernel, to: self()], []]}
    }

    fsm = start_supervised!(child_spec)

    {:ok, %{fsm: fsm}}
  end

  test "stream works correctly", %{fsm: fsm} do
    attrs = %{
      "to" => "egapp.im",
      "xmlns" => Const.xmlns_c2s(),
      "xmlns:stream" => Const.xmlns_stream(),
      "version" => Const.xmpp_version()
    }

    assert :continue = :gen_statem.call(fsm, {"stream:stream", attrs})
    assert_received resp
    resp = IO.chardata_to_string(resp)
    assert resp =~ "<stream:features"
  end

  test "stream fails with missing xmlns:stream attr", %{fsm: fsm} do
    attrs = %{
      "to" => "egapp.im",
      "xmlns" => Const.xmlns_c2s(),
      "version" => Const.xmpp_version()
    }

    assert :stop = :gen_statem.call(fsm, {"stream:stream", attrs})
    assert_received resp
    resp = IO.chardata_to_string(resp)
    assert resp =~ "<stream:error"
    assert resp =~ "<bad-namespace-prefix"
  end

  test "stream fails with missing version attr", %{fsm: fsm} do
    attrs = %{
      "to" => "egapp.im",
      "xmlns" => Const.xmlns_c2s(),
      "xmlns:stream" => Const.xmlns_stream()
    }

    assert :stop = :gen_statem.call(fsm, {"stream:stream", attrs})
    assert_received resp
    resp = IO.chardata_to_string(resp)
    assert resp =~ "<stream:error"
    assert resp =~ "<unsupported-version"
  end

  test "stream fails with missing all attrs", %{fsm: fsm} do
    attrs = %{}
    assert :stop = :gen_statem.call(fsm, {"stream:stream", attrs})
    assert_received resp
    resp = IO.chardata_to_string(resp)
    assert resp =~ "<stream:error"
    assert resp =~ "<bad-namespace-prefix"
  end

  test "stream passes without to attr", %{fsm: fsm} do
    attrs = %{
      "xmlns" => Const.xmlns_c2s(),
      "xmlns:stream" => Const.xmlns_stream(),
      "version" => Const.xmpp_version()
    }

    assert :continue = :gen_statem.call(fsm, {"stream:stream", attrs})
    assert_received resp
  end

  test "stream passes with invalid attr", %{fsm: fsm} do
    attrs = %{
      "foo" => "bar",
      "xmlns" => Const.xmlns_c2s(),
      "xmlns:stream" => Const.xmlns_stream(),
      "version" => Const.xmpp_version()
    }

    assert :continue = :gen_statem.call(fsm, {"stream:stream", attrs})
    assert_received resp
  end

  test "stream passes without xmlns attr", %{fsm: fsm} do
    attrs = %{
      "xmlns:stream" => Const.xmlns_stream(),
      "version" => Const.xmpp_version()
    }

    assert :continue = :gen_statem.call(fsm, {"stream:stream", attrs})
    assert_received resp
  end

  test "stream fails without tag prefix", %{fsm: fsm} do
    attrs = %{
      "to" => "egapp.im",
      "xmlns" => Const.xmlns_c2s(),
      "xmlns:stream" => Const.xmlns_stream(),
      "version" => Const.xmpp_version()
    }

    assert :stop = :gen_statem.call(fsm, {"stream", attrs})
    assert_received resp
    resp = IO.chardata_to_string(resp)
    assert resp =~ "<stream:error"
    assert resp =~ "<not-well-formed"
  end

  test "stream fails with invalid tag (state 1)", %{fsm: fsm} do
    attrs = %{
      "to" => "egapp.im",
      "xmlns" => Const.xmlns_c2s(),
      "xmlns:stream" => Const.xmlns_stream(),
      "version" => Const.xmpp_version()
    }

    assert :stop = :gen_statem.call(fsm, {"foo", attrs})
    assert_received resp
    resp = IO.chardata_to_string(resp)
    assert resp =~ "<stream:error"
    assert resp =~ "<not-well-formed"
  end

  @tag :skip
  test "auth works correctly" do
    child_spec = %{
      id: :temp_fsm,
      start: {Egapp.XMPP.FSM, :start_link, [[mod: Kernel, to: self(), init_state: :auth], []]}
    }
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Egapp.Repo)
    fsm = start_supervised!(child_spec)
    Ecto.Adapters.SQL.Sandbox.allow(Egapp.Repo, self(), fsm)
    attrs = %{
      "xmlns" => Const.xmlns_sasl(),
      "mechanism" => "PLAIN"
    }
    Egapp.Repo.insert!(%Egapp.Repo.User{username: "foo", password: "bar"})

    assert :continue = :gen_statem.call(fsm, {"auth", attrs, []})
    assert_received resp
    resp = IO.chardata_to_string(resp)
    assert resp =~ "foo"
  end

  test "bind works correctly" do
    child_spec = %{
      id: :temp_fsm,
      start: {Egapp.XMPP.FSM, :start_link, [[mod: Kernel, to: self(), init_state: :bind], []]}
    }
    attrs = %{"type" => "set"}
    data = [{:xmlel, "bind", [xmlns: Const.xmlns_bind], []}]
    fsm = start_supervised!(child_spec)
    :sys.replace_state(fsm, fn {state, data} ->
      jid = %Egapp.XMPP.Jid{
        localpart: "foo",
        domainpart: "bar",
        resourcepart: "123"
      }
      {state, put_in(data, [:client, :jid], jid)}
    end)
    assert :continue = :gen_statem.call(fsm, {"iq", attrs, data})
    assert_received resp
    resp = IO.chardata_to_string(resp)
    assert resp =~ "<bind"
    assert resp =~ "<jid"
  end
end
