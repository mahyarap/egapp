defmodule Egapp.Parser.FSMTest do
  use ExUnit.Case, async: true

  setup do
    {:ok, event_man} = GenServer.start_link(Egapp.Parser.EventManager, to: self(), mod: Kernel)
    {:ok, event_man: event_man}
  end

  test "can handle xml version", context do
    {:ok, fsm} =
      :gen_fsm.start_link(
        Egapp.Parser.FSM,
        [event_man: context[:event_man], init_state: :begin],
        []
      )

    xml_declaration = """
    <?xml version="1.0"?>\
    """

    :fxml_stream.new(fsm)
    |> :fxml_stream.parse(xml_declaration)

    result =
      receive do
        msg -> msg
      after
        10 -> :timeout
      end

    assert ^result = :timeout
  end

  test "can transition to initial state", context do
    {:ok, fsm} =
      :gen_fsm.start_link(
        Egapp.Parser.FSM,
        [event_man: context[:event_man], init_state: :begin],
        []
      )

    stream = """
    <stream:stream
    to="example.com"
    xmlns="jabber:client"
    xmlns:stream="http://etherx.jabber.org/streams"
    version="1.0">\
    """

    :fxml_stream.new(fsm)
    |> :fxml_stream.parse(stream)

    assert {:xml_stream_start, _} = :sys.get_state(fsm)

    result =
      receive do
        msg -> msg
      after
        10 -> raise "foo"
      end

    assert result =~ ~s(<?xml version="1.0"?>)
    assert result =~ ~s(<stream:stream)
    assert result =~ ~s(version="1.0")
    assert result =~ ~s(xml:lang="en")
  end

  # test "can transition to second state", context do
  #   {:ok, fsm} = :gen_fsm.start_link(
  #     Egapp.Parser.FSM,
  #     [event_man: context[:event_man], init_state: :begin],
  #     []
  #   )
  #   foo = """
  #   <stream:stream
  #   to="example.com"
  #   xmlns="jabber:client"
  #   xmlns:stream="http://etherx.jabber.org/streams"
  #   version="1.0">\
  #   """
  #   bar = """
  #   <iq>foo</iq>\
  #   """
  #   resp = """
  #   <iq>an</iq>
  #   """
  #   stream = :fxml_stream.new(fsm)
  #   stream = :fxml_stream.parse(stream, foo)
  #   stream = :fxml_stream.parse(stream, bar)
  #   assert_receive ^resp, 10
  # end

  # test "can transition to third state", context do
  #   {:ok, fsm} = :gen_fsm.start_link(
  #     Egapp.Parser.FSM,
  #     [event_man: context[:event_man], init_state: :begin],
  #     []
  #   )
  #   foo = """
  #   <stream:stream
  #   to="example.com"
  #   xmlns="jabber:client"
  #   xmlns:stream="http://etherx.jabber.org/streams"
  #   version="1.0">\
  #   """
  #   bar = """
  #   <iq>foo</iq>\
  #   """
  #   baz = """
  #   <message>hi</message>\
  #   """
  #   resp = """
  #   <message>hoy</message>
  #   """
  #   stream = :fxml_stream.new(fsm)
  #   stream = :fxml_stream.parse(stream, foo)
  #   stream = :fxml_stream.parse(stream, bar)
  #   stream = :fxml_stream.parse(stream, baz)
  #   assert_receive ^resp, 10
  # end
end
