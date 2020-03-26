defmodule Egapp.Parser.XML do
  @behaviour GenServer

  def start_link(args, opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  @impl true
  def init(args) do
    conn = Keyword.fetch!(args, :conn)
    {:ok, xmpp_fsm} = :gen_statem.start_link(Egapp.XMPP.FSM, [to: conn, mod: Egapp.Server], [])

    {:ok, xml_fsm} =
      Egapp.Parser.XML.FSM.start_link(xmpp_fsm: xmpp_fsm, parser: self())

    Process.monitor(xml_fsm)
    stream = :fxml_stream.new(xml_fsm, :infinity, [])
    {:ok, %{xml_fsm: xml_fsm, xmpp_fsm: xmpp_fsm, stream: stream, conn: conn}}
  end

  def parse(parser, data) do
    GenServer.cast(parser, data)
  end

  def reset(parser) do
    GenServer.call(parser, :reset)
  end

  @impl true
  def handle_call(:reset, _from, state) do
    :fxml_stream.reset(state.stream)
    {:reply, :ok, state}
  end

  @impl true
  def handle_cast(data, state) do
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
