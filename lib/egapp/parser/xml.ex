defmodule Egapp.Parser.XML do
  use Egapp.Parser

  @impl true
  def init(args) do
    conn = Keyword.fetch!(args, :conn)
    {:ok, xml_fsm} = Egapp.Parser.XML.FSM.start_link(conn: conn, parser: self())
    Process.monitor(xml_fsm)
    stream = :fxml_stream.new(xml_fsm, :infinity, [])
    {:ok, %{xml_fsm: xml_fsm, stream: stream, conn: conn}}
  end

  @impl true
  def handle_reset(state) do
    :fxml_stream.reset(state.stream)
    {:reply, :ok, state}
  end

  @impl true
  def handle_parse(data, state) do
    :fxml_stream.parse(state.stream, data)
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
