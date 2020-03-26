defmodule Egapp.Parser.XML.FSMTest do
  use ExUnit.Case, async: true

  require Egapp.Constants, as: Const

  setup do
    xml_fsm = start_supervised!({Egapp.Parser.XML.FSM, mod: Kernel, conn: self(), parser: nil})
    {:ok, %{xml_fsm: xml_fsm}}
  end

  test "transition from 1st to 2nd state", %{xml_fsm: xml_fsm} do
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
    refute Enum.empty?(resp)
  end

  test "transition from 1st to 2nd state with syntax error", %{xml_fsm: xml_fsm} do
    event = {:xmlstreamerror, {2, "syntax error"}}
    :gen_fsm.send_event(xml_fsm, event)

    catch_exit(:sys.get_state(xml_fsm))
    assert_received resp
    resp = IO.chardata_to_string(resp)
    assert resp =~ "<bad-format"
  end

  test "transition from 1st to 2nd state with not well formed stream", %{xml_fsm: xml_fsm} do
    event = {:xmlstreamerror, {4, "not well-formed (invalid token)"}}
    :gen_fsm.send_event(xml_fsm, event)

    catch_exit(:sys.get_state(xml_fsm))
    assert_received resp

    resp = IO.chardata_to_string(resp)
    assert resp =~ "<not-well-formed"
  end

  test "transition from 1st to 2nd state with unbound prefix", %{xml_fsm: xml_fsm} do
    event = {:xmlstreamerror, {27, "unbound prefix"}}
    :gen_fsm.send_event(xml_fsm, event)

    catch_exit(:sys.get_state(xml_fsm))
    assert_received resp

    resp = IO.chardata_to_string(resp)
    assert resp =~ "<not-well-formed"
  end

  test "transition from 1st to 2nd state with duplicate attributes", %{xml_fsm: xml_fsm} do
    event = {:xmlstreamerror, {8, "duplicate attribute"}}
    :gen_fsm.send_event(xml_fsm, event)

    catch_exit(:sys.get_state(xml_fsm))
    assert_received resp

    resp = IO.chardata_to_string(resp)
    assert resp =~ "<not-well-formed"
  end

  test "transition from 1st to 2nd state with no stream tag", %{xml_fsm: xml_fsm} do
    event = {:xmlstreamstart, "foo", []}
    :gen_fsm.send_event(xml_fsm, event)

    catch_exit(:sys.get_state(xml_fsm))
    assert_received resp

    resp = IO.chardata_to_string(resp)
    assert resp =~ "<not-well-formed"
  end

  @tag skip: "This needs to use a stub"
  test "transition from 2nd to 2nd state", %{xml_fsm: xml_fsm} do
    # Ecto.Adapters.SQL.Sandbox.allow(Egapp.Repo, self(), xmpp_fsm)
    # :sys.replace_state(xmpp_fsm, fn {_state, data} -> {:auth, data} end)
    :sys.replace_state(xml_fsm, fn {_state, data} -> {:xml_stream_element, data} end)

    assert {:xml_stream_element, _} = :sys.get_state(xml_fsm)

    attrs = [
      {"xmlns", Const.xmlns_sasl()},
      {"mechanism", "PLAIN"}
    ]

    event = {:xmlstreamelement, {:xmlel, "auth", attrs, []}}
    :gen_fsm.send_event(xml_fsm, event)

    assert {:xml_stream_element, _} = :sys.get_state(xml_fsm)
    assert_receive resp
    refute Enum.empty?(resp)
  end
end
