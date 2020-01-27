defmodule Egapp.Parser.XML do
  @behaviour GenServer

  @impl true
  def init(conn) do
    {:ok, event_man} = :gen_statem.start_link(Egapp.XMPP.FSM, [to: conn, mod: Egapp.Server], [])
    {:ok, fsm} = :gen_fsm.start_link(Egapp.Parser.XML.FSM, [event_man: event_man], [])
    Process.monitor(fsm)
    stream = :fxml_stream.new(fsm, :infinity, [])
    {:ok, %{fsm: fsm, event_man: event_man, stream: stream, conn: conn}}
  end

  def parse(parser, data) do
    GenServer.cast(parser, data)
  end

  @impl true
  def handle_cast(data, state) do
    case :sys.get_state(state.fsm) do
      {:begin, _} ->
        :fxml_stream.reset(state.stream)
        :fxml_stream.parse(state.stream, data)

      _ ->
        :fxml_stream.parse(state.stream, data)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    case msg do
      {:DOWN, _, :process, _, _} -> :gen_tcp.close(state.conn)
    end

    {:stop, :normal, state}
  end
end
