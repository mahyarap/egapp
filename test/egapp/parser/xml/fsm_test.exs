defmodule Egapp.Parser.XML.FSMTest do
  use ExUnit.Case, async: true

  setup_all do
    Application.ensure_all_started(:fast_xml)
    :ok
  end

  setup do
    xmpp_fsm = start_supervised!({Egapp.XMPP.FSM, to: self(), mod: Kernel})
    {:ok, xmpp_fsm: xmpp_fsm}
  end

  test "transition from 1st to 2nd state", %{xmpp_fsm: xmpp_fsm} do
    fsm =
      start_supervised!(
        {Egapp.Parser.XML.FSM, xmpp_fsm: xmpp_fsm, parser: nil, init_state: :xml_stream_start}
      )

    stream = """
    <?xml version="1.0"?>
    <stream:stream
    to="example.com"
    xmlns="jabber:client"
    xmlns:stream="http://etherx.jabber.org/streams"
    version="1.0">\
    """

    assert {:xml_stream_start, _} = :sys.get_state(fsm)

    :fxml_stream.new(fsm)
    |> :fxml_stream.parse(stream)

    assert {:xml_stream_element, _} = :sys.get_state(fsm)
    assert_received resp
    refute Enum.empty?(resp)
  end

  test "transition from 1st to 2nd state with syntax error", %{xmpp_fsm: xmpp_fsm} do
    fsm =
      start_supervised!(
        {Egapp.Parser.XML.FSM, xmpp_fsm: xmpp_fsm, parser: nil, init_state: :xml_stream_start}
      )

    stream = "syntax error"

    :fxml_stream.new(fsm)
    |> :fxml_stream.parse(stream)

    catch_exit(:sys.get_state(fsm))
    assert_received resp

    resp = IO.chardata_to_string(resp)
    assert resp =~ "<bad-format"
  end

  test "transition from 1st to 2nd state with not well formed stream", %{xmpp_fsm: xmpp_fsm} do
    fsm =
      start_supervised!(
        {Egapp.Parser.XML.FSM, xmpp_fsm: xmpp_fsm, parser: nil, init_state: :xml_stream_start}
      )

    stream = """
    <?>
    """

    :fxml_stream.new(fsm)
    |> :fxml_stream.parse(stream)

    catch_exit(:sys.get_state(fsm))
    assert_received resp

    resp = IO.chardata_to_string(resp)
    assert resp =~ "<not-well-formed"
  end

  test "transition from 1st to 2nd state with unbound prefix", %{xmpp_fsm: xmpp_fsm} do
    fsm =
      start_supervised!(
        {Egapp.Parser.XML.FSM, xmpp_fsm: xmpp_fsm, parser: nil, init_state: :xml_stream_start}
      )

    stream = """
    <stream:stream>
    """

    :fxml_stream.new(fsm)
    |> :fxml_stream.parse(stream)

    catch_exit(:sys.get_state(fsm))
    assert_received resp

    resp = IO.chardata_to_string(resp)
    assert resp =~ "<not-well-formed"
  end

  test "transition from 1st to 2nd state with duplicate attributes", %{xmpp_fsm: xmpp_fsm} do
    fsm =
      start_supervised!(
        {Egapp.Parser.XML.FSM, xmpp_fsm: xmpp_fsm, parser: nil, init_state: :xml_stream_start}
      )

    stream = """
    <stream:stream foo="bar" foo="bar">
    """

    :fxml_stream.new(fsm)
    |> :fxml_stream.parse(stream)

    catch_exit(:sys.get_state(fsm))
    assert_received resp

    resp = IO.chardata_to_string(resp)
    assert resp =~ "<not-well-formed"
  end

  test "transition from 1st to 2nd state with no stream tag", %{xmpp_fsm: xmpp_fsm} do
    fsm =
      start_supervised!(
        {Egapp.Parser.XML.FSM, xmpp_fsm: xmpp_fsm, parser: nil, init_state: :xml_stream_start}
      )

    stream = "<foo>"

    :fxml_stream.new(fsm)
    |> :fxml_stream.parse(stream)

    catch_exit(:sys.get_state(fsm))
    assert_received resp

    resp = IO.chardata_to_string(resp)
    assert resp =~ "<not-well-formed"
  end

  # @tag :skip
  test "transition from 2nd to 2nd state", %{xmpp_fsm: xmpp_fsm} do
    fsm =
      start_supervised!(
        {Egapp.Parser.XML.FSM, xmpp_fsm: xmpp_fsm, parser: nil, init_state: :xml_stream_start}
      )

    stream_header = """
    <stream:stream
    to="example.com"
    xmlns="jabber:client"
    xmlns:stream="http://etherx.jabber.org/streams"
    version="1.0">\
    """

    iq = """
    <iq type='set' id='purple35aab1c4'><session xmlns='urn:ietf:params:xml:ns:xmpp-session'/></iq>\
    """

    assert {:xml_stream_start, _} = :sys.get_state(fsm)

    stream =
      :fxml_stream.new(fsm)
      |> :fxml_stream.parse(stream_header)

    assert {:xml_stream_element, _} = :sys.get_state(fsm)

    :fxml_stream.parse(stream, iq)

    assert {:xml_stream_element, _} = :sys.get_state(fsm)
    assert_receive resp
    assert not Enum.empty?(resp)
  end
end
