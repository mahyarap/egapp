defmodule Egapp.Parser.XML.FSMTest do
  use ExUnit.Case, async: true

  require Egapp.Constants, as: Const

  describe "in 1st state and no stub" do
    setup do
      Process.flag(:trap_exit, true)
      {:ok, xml_fsm} = Egapp.Parser.XML.FSM.start_link(mod: Kernel, conn: self(), parser: nil)
      {:ok, %{xml_fsm: xml_fsm}}
    end

    test "when everything is correct", %{xml_fsm: xml_fsm} do
      assert {:xml_stream_start, _} = :sys.get_state(xml_fsm)

      event = {
        :xmlstreamstart,
        "stream:stream",
        [
          {"to", "example.com"},
          {"xmlns", Const.xmlns_c2s()},
          {"xmlns:stream", Const.xmlns_stream()},
          {"version", Const.xmpp_version()}
        ]
      }

      :gen_fsm.send_event(xml_fsm, event)

      assert {:xml_stream_element, _} = :sys.get_state(xml_fsm)
      assert_received resp
      resp = IO.chardata_to_string(resp)

      assert resp =~ ~s(<stream:stream)
    end

    test "with syntax error", %{xml_fsm: xml_fsm} do
      event = {:xmlstreamerror, {2, "syntax error"}}
      :gen_fsm.send_event(xml_fsm, event)

      assert_receive resp
      resp = IO.chardata_to_string(resp)
      assert resp =~ "<bad-format"
      assert_receive {:EXIT, _, :normal}
    end

    test "with not well formed stream", %{xml_fsm: xml_fsm} do
      event = {:xmlstreamerror, {4, "not well-formed (invalid token)"}}
      :gen_fsm.send_event(xml_fsm, event)

      assert_receive resp
      resp = IO.chardata_to_string(resp)
      assert resp =~ "<not-well-formed"
      assert_receive {:EXIT, _, :normal}
    end

    test "with unbound prefix", %{xml_fsm: xml_fsm} do
      event = {:xmlstreamerror, {27, "unbound prefix"}}
      :gen_fsm.send_event(xml_fsm, event)

      assert_receive resp
      resp = IO.chardata_to_string(resp)
      assert resp =~ "<not-well-formed"
      assert_receive {:EXIT, _, :normal}
    end

    test "with duplicate attributes", %{xml_fsm: xml_fsm} do
      event = {:xmlstreamerror, {8, "duplicate attribute"}}
      :gen_fsm.send_event(xml_fsm, event)

      assert_receive resp
      resp = IO.chardata_to_string(resp)
      assert resp =~ "<not-well-formed"
      assert_receive {:EXIT, _, :normal}
    end

    test "with no stream tag", %{xml_fsm: xml_fsm} do
      event = {:xmlstreamstart, "foo", []}
      :gen_fsm.send_event(xml_fsm, event)

      assert_receive resp
      resp = IO.chardata_to_string(resp)
      assert resp =~ "<not-well-formed"
      assert_receive {:EXIT, _, :normal}
    end
  end

  defmodule XMPPFSMStub do
    @behaviour :gen_statem

    @impl true
    def callback_mode, do: :state_functions

    @impl true
    def init(_args), do: {:ok, :stream_init, []}

    def start_link(args, opts \\ []), do: :gen_statem.start_link(__MODULE__, args, opts)

    def stream_init({:call, from}, {"stream:stream", _attrs}, state) do
      {:next_state, :stream_element, state, {:reply, from, :continue}}
    end

    def auth({:call, from}, {"auth", _attrs, ["pass"]}, state) do
      {:next_state, :stream_init, state, {:reply, from, :reset}}
    end

    def auth({:call, from}, {"auth", _attrs, ["nopass"]}, state) do
      {:next_state, :stream_init, state, {:reply, from, :continue}}
    end
  end

  defmodule ParserStub do
    use Egapp.Parser

    def start_link(args), do: Egapp.Parser.start_link(__MODULE__, args, [])

    def init(_args), do: {:ok, []}

    def handle_reset(state), do: {:reply, :ok, state}

    def handle_parse(_data, state), do: {:noreply, state}
  end

  describe "in 2nd state and parser and fsm being stubbed" do
    setup do
      parser = start_supervised!(ParserStub)

      xml_fsm =
        start_supervised!(
          {Egapp.Parser.XML.FSM, mod: Kernel, conn: self(), parser: parser, xmpp_fsm: XMPPFSMStub}
        )

      :sys.replace_state(xml_fsm, fn {_state, %{xmpp_fsm: xmpp_fsm} = data} ->
        :sys.replace_state(xmpp_fsm, fn {_state, data} -> {:auth, data} end)
        {:xml_stream_element, data}
      end)

      {:ok, %{xml_fsm: xml_fsm}}
    end

    test "when auth succeeds", %{xml_fsm: xml_fsm} do
      assert {:xml_stream_element, _} = :sys.get_state(xml_fsm)

      attrs = [
        {"xmlns", Const.xmlns_sasl()},
        {"mechanism", "PLAIN"}
      ]

      data = [xmlcdata: "pass"]
      event = {:xmlstreamelement, {:xmlel, "auth", attrs, data}}
      :gen_fsm.send_event(xml_fsm, event)

      assert {:xml_stream_start, _} = :sys.get_state(xml_fsm)
    end

    test "when auth fails", %{xml_fsm: xml_fsm} do
      assert {:xml_stream_element, _} = :sys.get_state(xml_fsm)

      attrs = [
        {"xmlns", Const.xmlns_sasl()},
        {"mechanism", "PLAIN"}
      ]

      data = [xmlcdata: "nopass"]
      event = {:xmlstreamelement, {:xmlel, "auth", attrs, data}}
      :gen_fsm.send_event(xml_fsm, event)

      assert {:xml_stream_element, _} = :sys.get_state(xml_fsm)
    end
  end

  describe "in 2nd state and parser stubbed" do
    setup do
      Process.flag(:trap_exit, true)
      {:ok, xml_fsm} = Egapp.Parser.XML.FSM.start_link(mod: Kernel, conn: self(), parser: nil)

      :sys.replace_state(xml_fsm, fn {_state, %{xmpp_fsm: xmpp_fsm} = data} ->
        :sys.replace_state(xmpp_fsm, fn {_state, data} -> {:auth, data} end)
        {:xml_stream_element, data}
      end)

      {:ok, %{xml_fsm: xml_fsm}}
    end

    test "with syntax error", %{xml_fsm: xml_fsm} do
      event = {:xmlstreamerror, {2, "syntax error"}}
      :gen_fsm.send_event(xml_fsm, event)

      assert_receive resp
      resp = IO.chardata_to_string(resp)
      assert resp =~ "<bad-format"
      assert_receive {:EXIT, _, :normal}
    end

    test "with not well formed stream", %{xml_fsm: xml_fsm} do
      event = {:xmlstreamerror, {4, "not well-formed (invalid token)"}}
      :gen_fsm.send_event(xml_fsm, event)

      assert_receive resp
      resp = IO.chardata_to_string(resp)
      assert resp =~ "<not-well-formed"
      assert_receive {:EXIT, _, :normal}
    end

    test "with unbound prefix", %{xml_fsm: xml_fsm} do
      event = {:xmlstreamerror, {27, "unbound prefix"}}
      :gen_fsm.send_event(xml_fsm, event)

      assert_receive resp
      resp = IO.chardata_to_string(resp)
      assert resp =~ "<not-well-formed"
      assert_receive {:EXIT, _, :normal}
    end

    test "with duplicate attributes", %{xml_fsm: xml_fsm} do
      event = {:xmlstreamerror, {8, "duplicate attribute"}}
      :gen_fsm.send_event(xml_fsm, event)

      assert_receive resp
      resp = IO.chardata_to_string(resp)
      assert resp =~ "<not-well-formed"
      assert_receive {:EXIT, _, :normal}
    end

    test "with invalid tag", %{xml_fsm: xml_fsm} do
      event = {:xmlstreamelement, {:xmlel, "foo", %{}, []}}
      :gen_fsm.send_event(xml_fsm, event)

      assert_receive resp
      resp = IO.chardata_to_string(resp)
      assert resp =~ "<not-well-formed"
      assert_receive {:EXIT, _, :normal}
    end

    test "with stream end", %{xml_fsm: xml_fsm} do
      event = {:xmlstreamend, :end}
      :gen_fsm.send_event(xml_fsm, event)

      assert_receive resp
      resp = IO.chardata_to_string(resp)
      assert resp =~ "</stream:stream>"
      assert_receive {:EXIT, _, :normal}
    end
  end
end
