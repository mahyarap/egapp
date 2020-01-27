defmodule Egapp.Parser.FSMTest do
  use ExUnit.Case, async: true

  alias Egapp.Parser.XML.FSM
  alias Egapp.Parser.XML.EventMan

  setup do
    event_man = start_supervised!({EventMan, to: self(), mod: Kernel})
    {:ok, event_man: event_man}
  end

  test "can transition to initial state", %{event_man: event_man} do
    fsm = start_supervised!({FSM, event_man: event_man, init_state: :begin})

    stream = """
    <?xml version="1.0"?>
    <stream:stream
    to="example.com"
    xmlns="jabber:client"
    xmlns:stream="http://etherx.jabber.org/streams"
    version="1.0">\
    """

    assert {:begin, _} = :sys.get_state(fsm)

    :fxml_stream.new(fsm)
    |> :fxml_stream.parse(stream)

    assert {:xml_stream_start, _} = :sys.get_state(fsm)
    assert_received resp
    assert not Enum.empty?(resp)
  end

  test "stream with syntax error", %{event_man: event_man} do
    fsm = start_supervised!({FSM, event_man: event_man, init_state: :begin})

    stream = "syntax error"

    :fxml_stream.new(fsm)
    |> :fxml_stream.parse(stream)

    catch_exit(:sys.get_state(fsm))
    assert_received resp

    resp = IO.chardata_to_string(resp)
    assert resp =~ "<bad-format"
  end

  test "not well formed stream", %{event_man: event_man} do
    fsm = start_supervised!({FSM, event_man: event_man, init_state: :begin})

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

  test "stream with unbound prefix", %{event_man: event_man} do
    fsm = start_supervised!({FSM, event_man: event_man, init_state: :begin})

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

  test "stream with duplicate attributes", %{event_man: event_man} do
    fsm = start_supervised!({FSM, event_man: event_man, init_state: :begin})

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

  test "no stream tag", %{event_man: event_man} do
    fsm = start_supervised!({FSM, event_man: event_man, init_state: :begin})

    stream = "<foo>"

    :fxml_stream.new(fsm)
    |> :fxml_stream.parse(stream)

    catch_exit(:sys.get_state(fsm))
    assert_received resp

    resp = IO.chardata_to_string(resp)
    assert resp =~ "<not-well-formed"
  end

  @tag :skip
  test "can transition to second state", %{event_man: event_man} do
    fsm = start_supervised!({FSM, event_man: event_man, init_state: :begin})

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

    assert {:begin, _} = :sys.get_state(fsm)

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
