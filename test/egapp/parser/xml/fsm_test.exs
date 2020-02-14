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

  test "can transition to initial state", %{xmpp_fsm: xmpp_fsm} do
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
    assert not Enum.empty?(resp)
  end

  test "stream with syntax error", %{xmpp_fsm: xmpp_fsm} do
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

  test "not well formed stream", %{xmpp_fsm: xmpp_fsm} do
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

  test "stream with unbound prefix", %{xmpp_fsm: xmpp_fsm} do
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

  test "stream with duplicate attributes", %{xmpp_fsm: xmpp_fsm} do
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

  test "no stream tag", %{xmpp_fsm: xmpp_fsm} do
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

  @tag :skip
  test "can transition to second state", %{xmpp_fsm: xmpp_fsm} do
    fsm =
      start_supervised!(
        {Egapp.Parser.XML.FSM, xmpp_fsm: xmpp_fsm, parser: nil, init_state: :xml_stream_start}
      )

    foo = """
    <stream:stream
    to="example.com"
    xmlns="jabber:client"
    xmlns:stream="http://etherx.jabber.org/streams"
    version="1.0">\
    """

    bar = """
    <iq type='set' id='purple35aab1c4'><session xmlns='urn:ietf:params:xml:ns:xmpp-session'/></iq>\
    """

    assert {:xml_stream_start, _} = :sys.get_state(fsm)

    stream =
      :fxml_stream.new(fsm)
      |> :fxml_stream.parse(foo)

    assert {:xml_stream_start, _} = :sys.get_state(fsm)
    :fxml_stream.parse(stream, bar)

    assert {:xml_stream_element, _} = :sys.get_state(fsm)

    assert_receive resp
    assert not Enum.empty?(resp)
  end
end
