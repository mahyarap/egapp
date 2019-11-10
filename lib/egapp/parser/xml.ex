defmodule Egapp.Parser.XML do
  alias Egapp.Parser.XML.EventMan
  alias Egapp.Parser.XML.FSM

  @behaviour Egapp.Parser

  @impl Egapp.Parser
  def parse(conn) do
    {:ok, pid} = GenServer.start_link(EventMan, [to: conn, mod: Egapp.Server])
    {:ok, pid} = :gen_fsm.start_link(FSM, [event_man: pid], [])
    stream = :fxml_stream.new(pid, :infinity, [])
    loop(conn, stream, pid)
  end

  defp loop(conn, stream, fsm) do
    case Egapp.Server.recv(conn) do
      {:ok, packet} ->
        case :sys.get_state(fsm) do
          {:begin, _} ->
            :fxml_stream.reset(stream)
            :fxml_stream.parse(stream, packet)
          _ ->
            :fxml_stream.parse(stream, packet)
        end
      {:error, :closed} -> exit(:normal)
      _ -> raise("recv read")
    end
    loop(conn, stream, fsm)
  end
end
