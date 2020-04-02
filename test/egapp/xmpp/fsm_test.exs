defmodule Egapp.XMPP.FSMTest do
  use ExUnit.Case, async: true

  require Egapp.Constants, as: Const

  describe "in 1st state" do
    setup do
      Process.flag(:trap_exit, true)
      {:ok, fsm} = Egapp.XMPP.FSM.start_link(mod: Kernel, to: self())
      {:ok, %{fsm: fsm}}
    end

    test "when attrs correct and not authenticated", %{fsm: fsm} do
      attrs = %{
        "to" => "egapp.im",
        "xmlns" => Const.xmlns_c2s(),
        "xmlns:stream" => Const.xmlns_stream(),
        "version" => Const.xmpp_version()
      }

      assert {:stream_init, _} = :sys.get_state(fsm)
      assert :continue = :gen_statem.call(fsm, {"stream:stream", attrs})
      assert {:auth, _} = :sys.get_state(fsm)
      assert_received resp
      resp = IO.chardata_to_string(resp)
      assert resp =~ "<stream:features"
    end

    test "when attrs not correct and not authenticated", %{fsm: fsm} do
      attrs = %{
        "to" => "egapp.im",
        "xmlns" => Const.xmlns_c2s(),
        "xmlns:stream" => "fooooooooo",
        "version" => Const.xmpp_version()
      }

      assert {:stream_init, _} = :sys.get_state(fsm)
      assert :stop = :gen_statem.call(fsm, {"stream:stream", attrs})
      assert_received resp
      resp = IO.chardata_to_string(resp)
      assert resp =~ "<stream:error"
      assert_received {:EXIT, _, :normal}
    end

    test "when attrs correct and authenticated", %{fsm: fsm} do
      attrs = %{
        "to" => "egapp.im",
        "xmlns" => Const.xmlns_c2s(),
        "xmlns:stream" => Const.xmlns_stream(),
        "version" => Const.xmpp_version()
      }

      assert {:stream_init, _} = :sys.get_state(fsm)

      :sys.replace_state(fsm, fn {state, data} ->
        data = put_in(data, [:client, :is_authenticated], true)
        {state, data}
      end)

      assert :continue = :gen_statem.call(fsm, {"stream:stream", attrs})
      assert {:bind, _} = :sys.get_state(fsm)
      assert_received resp
      resp = IO.chardata_to_string(resp)
      assert resp =~ "<stream:features"
    end

    test "when attrs not correct and authenticated", %{fsm: fsm} do
      attrs = %{
        "to" => "egapp.im",
        "xmlns" => Const.xmlns_c2s(),
        "xmlns:stream" => "fooooooo",
        "version" => Const.xmpp_version()
      }

      assert {:stream_init, _} = :sys.get_state(fsm)

      :sys.replace_state(fsm, fn {state, data} ->
        data = put_in(data, [:client, :is_authenticated], true)
        {state, data}
      end)

      assert :stop = :gen_statem.call(fsm, {"stream:stream", attrs})
      assert_received resp
      resp = IO.chardata_to_string(resp)
      assert resp =~ "<stream:error"
      assert_received {:EXIT, _, :normal}
    end

    test "with syntax error", %{fsm: fsm} do
      assert {:stream_init, _} = :sys.get_state(fsm)
      assert :stop = :gen_statem.call(fsm, {:error, {2, "syntax error"}})
      assert_received resp
      resp = IO.chardata_to_string(resp)
      assert resp =~ "<stream:error"
      assert_received {:EXIT, _, :normal}
    end

    test "with tag other than stream", %{fsm: fsm} do
      assert {:stream_init, _} = :sys.get_state(fsm)
      assert :stop = :gen_statem.call(fsm, {"foo", %{}})
      assert_received resp
      resp = IO.chardata_to_string(resp)
      assert resp =~ "<stream:error"
      assert_received {:EXIT, _, :normal}
    end
  end

  defmodule SASLPlainStub do
    @behaviour Egapp.SASL

    def type, do: :plain
    def authenticate("pass"), do: {:ok, %{username: "foo", id: 1}}
    def authenticate("nopass"), do: {:error, %{}}
  end

  defmodule JidConnRegistryStub do
    @behaviour Egapp.JidConnRegistry

    def put(_key, _val), do: nil
    def match(_key), do: nil
  end

  describe "in 2nd state" do
    setup do
      Process.flag(:trap_exit, true)

      {:ok, fsm} =
        Egapp.XMPP.FSM.start_link(
          mod: Kernel,
          to: self(),
          sasl_mechanisms: [SASLPlainStub],
          jid_conn_registry: JidConnRegistryStub
        )

      :sys.replace_state(fsm, fn {_state, data} -> {:auth, data} end)
      {:ok, %{fsm: fsm}}
    end

    test "when authentication succeeds", %{fsm: fsm} do
      attrs = %{"xmlns" => Const.xmlns_sasl(), "mechanism" => "PLAIN"}
      assert :reset = :gen_statem.call(fsm, {"auth", attrs, ["pass"]})
      assert_received resp
      resp = IO.chardata_to_string(resp)
      assert resp =~ "<success"
    end

    test "when authentication fails", %{fsm: fsm} do
      attrs = %{"xmlns" => Const.xmlns_sasl(), "mechanism" => "PLAIN"}
      assert :continue = :gen_statem.call(fsm, {"auth", attrs, ["nopass"]})
      assert_received resp
      resp = IO.chardata_to_string(resp)
      assert resp =~ "<failure"
    end

    test "when stream ends", %{fsm: fsm} do
      assert :stop = :gen_statem.call(fsm, :end)
      assert_received resp
      resp = IO.chardata_to_string(resp)
      assert resp =~ "</stream:stream>"
      assert_received {:EXIT, _, :normal}
    end

    test "with syntax error", %{fsm: fsm} do
      assert :stop = :gen_statem.call(fsm, {:error, {2, "syntax error"}})
      assert_received resp
      resp = IO.chardata_to_string(resp)
      assert resp =~ "<stream:error"
      assert_received {:EXIT, _, :normal}
    end

    test "with unknown tag", %{fsm: fsm} do
      assert :stop = :gen_statem.call(fsm, {"foo", %{}, []})
      assert_received resp
      resp = IO.chardata_to_string(resp)
      assert resp =~ "<stream:error"
      assert_received {:EXIT, _, :normal}
    end
  end

  describe "in 3rd state" do
    setup do
      Process.flag(:trap_exit, true)
      {:ok, fsm} = Egapp.XMPP.FSM.start_link(mod: Kernel, to: self())
      :sys.replace_state(fsm, fn {_state, data} -> {:bind, data} end)
      {:ok, %{fsm: fsm}}
    end

    test "when bind succeeds", %{fsm: fsm} do
      :sys.replace_state(fsm, fn {_state, data} ->
        jid = %Egapp.XMPP.Jid{
          localpart: "foo",
          domainpart: "bar",
          resourcepart: "123"
        }

        {:bind, put_in(data, [:client, :jid], jid)}
      end)

      attrs = %{"type" => "set", "id" => "abc"}
      data = [{"bind", %{"xmlns" => Const.xmlns_bind()}, []}]

      assert :continue = :gen_statem.call(fsm, {"iq", attrs, data})
      assert_received resp
      resp = IO.chardata_to_string(resp)
      assert resp =~ "<bind"
      assert resp =~ "<jid"
    end

    test "when stream ends", %{fsm: fsm} do
      assert :stop = :gen_statem.call(fsm, :end)
      assert_received resp
      resp = IO.chardata_to_string(resp)
      assert resp =~ "</stream:stream>"
      assert_received {:EXIT, _, :normal}
    end

    test "with syntax error", %{fsm: fsm} do
      assert :stop = :gen_statem.call(fsm, {:error, {2, "syntax error"}})
      assert_received resp
      resp = IO.chardata_to_string(resp)
      assert resp =~ "<stream:error"
      assert_received {:EXIT, _, :normal}
    end

    test "with unknown tag", %{fsm: fsm} do
      assert :stop = :gen_statem.call(fsm, {"foo", %{}, []})
      assert_received resp
      resp = IO.chardata_to_string(resp)
      assert resp =~ "<stream:error"
      assert_received {:EXIT, _, :normal}
    end
  end

  describe "in 4th state" do
    setup do
      Process.flag(:trap_exit, true)
      {:ok, fsm} = Egapp.XMPP.FSM.start_link(mod: Kernel, to: self(), jid_conn_registry: JidConnRegistryStub)
      :sys.replace_state(fsm, fn {_state, data} -> {:stanza, data} end)
      {:ok, %{fsm: fsm}}
    end

    test "when iq stanza succeeds", %{fsm: fsm} do
      attrs = %{"type" => "set", "id" => "123"}
      data = [{"session", %{"xmlns" => Const.xmlns_session()}, []}]
      assert :continue = :gen_statem.call(fsm, {"iq", attrs, data})
      assert_received resp
      resp = IO.chardata_to_string(resp)
      assert resp =~ "<iq"
    end

    @tag :skip
    test "when presence stanza succeeds", %{fsm: fsm} do
      attrs = %{"type" => "set", "id" => "123"}
      data = [{"session", %{"xmlns" => Const.xmlns_session()}, []}]
      assert :continue = :gen_statem.call(fsm, {"presence", attrs, data})
      assert_received resp
      resp = IO.chardata_to_string(resp)
      assert resp =~ "<iq"
    end

    @tag :skip
    test "when message succeeds", %{fsm: fsm} do
      alias Egapp.XMPP.Jid
      :sys.replace_state(fsm, fn {state, data} ->
        data = put_in(data, [:client, :jid], %Jid{localpart: "john", domainpart: "egapp.im", resourcepart: "123"})
        {state, data}
      end)
      attrs = %{"type" => "chat", "to" => "foo@bar/456"}
      data = [{"body", %{}, ["hi"]}]
      assert :continue = :gen_statem.call(fsm, {"message", attrs, data})
      assert_receive resp
    end

    test "when stream ends", %{fsm: fsm} do
      assert :stop = :gen_statem.call(fsm, :end)
      assert_received resp
      resp = IO.chardata_to_string(resp)
      assert resp =~ "</stream:stream>"
      assert_received {:EXIT, _, :normal}
    end

    test "with syntax error", %{fsm: fsm} do
      assert :stop = :gen_statem.call(fsm, {:error, {2, "syntax error"}})
      assert_received resp
      resp = IO.chardata_to_string(resp)
      assert resp =~ "<stream:error"
      assert_received {:EXIT, _, :normal}
    end

    test "with unknown tag", %{fsm: fsm} do
      assert :stop = :gen_statem.call(fsm, {"foo", %{}, []})
      assert_received resp
      resp = IO.chardata_to_string(resp)
      assert resp =~ "<stream:error"
      assert_received {:EXIT, _, :normal}
    end
  end
end
