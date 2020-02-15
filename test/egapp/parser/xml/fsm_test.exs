defmodule Egapp.Parser.XML.FSMTest do
  use ExUnit.Case, async: true

  require Egapp.Constants, as: Const

  test "can transition to initial state" do
    xmpp_fsm = start_supervised!({Egapp.XMPP.FSM, to: self(), mod: Kernel})

    fsm =
      start_supervised!(
        {Egapp.Parser.XML.FSM, xmpp_fsm: xmpp_fsm, parser: nil, init_state: :xml_stream_start}
      )

    assert {:xml_stream_start, _} = :sys.get_state(fsm)

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

    :gen_fsm.send_event(fsm, event)

    assert {:xml_stream_element, _} = :sys.get_state(fsm)
    assert_received resp
    refute Enum.empty?(resp)
  end

  test "stream with syntax error" do
    xmpp_fsm = start_supervised!({Egapp.XMPP.FSM, to: self(), mod: Kernel})

    fsm =
      start_supervised!(
        {Egapp.Parser.XML.FSM, xmpp_fsm: xmpp_fsm, parser: nil, init_state: :xml_stream_start}
      )

    event = {:xmlstreamerror, {2, "syntax error"}}
    :gen_fsm.send_event(fsm, event)

    catch_exit(:sys.get_state(fsm))
    assert_received resp
    resp = IO.chardata_to_string(resp)
    assert resp =~ "<bad-format"
  end

  test "not well formed stream" do
    xmpp_fsm = start_supervised!({Egapp.XMPP.FSM, to: self(), mod: Kernel})

    fsm =
      start_supervised!(
        {Egapp.Parser.XML.FSM, xmpp_fsm: xmpp_fsm, parser: nil, init_state: :xml_stream_start}
      )

    event = {:xmlstreamerror, {4, "not well-formed (invalid token)"}}
    :gen_fsm.send_event(fsm, event)

    catch_exit(:sys.get_state(fsm))
    assert_received resp

    resp = IO.chardata_to_string(resp)
    assert resp =~ "<not-well-formed"
  end

  test "stream with unbound prefix" do
    xmpp_fsm = start_supervised!({Egapp.XMPP.FSM, to: self(), mod: Kernel})

    fsm =
      start_supervised!(
        {Egapp.Parser.XML.FSM, xmpp_fsm: xmpp_fsm, parser: nil, init_state: :xml_stream_start}
      )

    event = {:xmlstreamerror, {27, "unbound prefix"}}
    :gen_fsm.send_event(fsm, event)

    catch_exit(:sys.get_state(fsm))
    assert_received resp

    resp = IO.chardata_to_string(resp)
    assert resp =~ "<not-well-formed"
  end

  test "stream with duplicate attributes" do
    xmpp_fsm = start_supervised!({Egapp.XMPP.FSM, to: self(), mod: Kernel})

    fsm =
      start_supervised!(
        {Egapp.Parser.XML.FSM, xmpp_fsm: xmpp_fsm, parser: nil, init_state: :xml_stream_start}
      )

    event = {:xmlstreamerror, {8, "duplicate attribute"}}
    :gen_fsm.send_event(fsm, event)

    catch_exit(:sys.get_state(fsm))
    assert_received resp

    resp = IO.chardata_to_string(resp)
    assert resp =~ "<not-well-formed"
  end

  test "no stream tag" do
    xmpp_fsm = start_supervised!({Egapp.XMPP.FSM, to: self(), mod: Kernel})

    fsm =
      start_supervised!(
        {Egapp.Parser.XML.FSM, xmpp_fsm: xmpp_fsm, parser: nil, init_state: :xml_stream_start}
      )

    event = {:xmlstreamstart, "foo", []}
    :gen_fsm.send_event(fsm, event)

    catch_exit(:sys.get_state(fsm))
    assert_received resp

    resp = IO.chardata_to_string(resp)
    assert resp =~ "<not-well-formed"
  end

  test "can transition to second state" do
    start_supervised!(Egapp.Repo)
    xmpp_fsm = start_supervised!({Egapp.XMPP.FSM, to: self(), mod: Kernel, init_state: :auth})

    fsm =
      start_supervised!(
        {Egapp.Parser.XML.FSM, xmpp_fsm: xmpp_fsm, parser: nil, init_state: :xml_stream_element}
      )

    assert {:xml_stream_element, _} = :sys.get_state(fsm)

    attrs = [
      {"xmlns", Const.xmlns_sasl()},
      {"mechanism", "PLAIN"}
    ]

    event = {:xmlstreamelement, {:xmlel, "auth", attrs, []}}
    :gen_fsm.send_event(fsm, event)

    assert {:xml_stream_element, _} = :sys.get_state(fsm)
    assert_receive resp
    refute Enum.empty?(resp)
  end
end
