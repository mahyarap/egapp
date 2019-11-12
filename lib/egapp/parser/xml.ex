defmodule Egapp.Parser.XML do
  alias Egapp.Parser.XML.EventMan
  alias Egapp.Parser.XML.FSM

  @behaviour GenServer

  @impl true
  def init(conn) do
    {:ok, pid} = GenServer.start_link(EventMan, [to: conn, mod: Egapp.Server])
    {:ok, pid} = :gen_fsm.start_link(FSM, [event_man: pid], [])
    Process.monitor(pid)
    stream = :fxml_stream.new(pid, :infinity, [])
    {:ok, %{fsm: pid, stream: stream, conn: conn}}
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
    IO.inspect {msg, state}
    :gen_tcp.close(state.conn)
    {:stop, :normal, state}
  end
end
