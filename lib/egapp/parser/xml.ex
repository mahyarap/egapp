defmodule Egapp.Parser.XML do
  alias Egapp.Parser.XML.EventMan
  alias Egapp.Parser.XML.FSM

  @behaviour Egapp.Parser

  @impl Egapp.Parser
  def parse(conn) do
    {:ok, pid} = GenServer.start_link(EventMan, [to: conn, mod: Egapp.Server])
    {:ok, pid} = :gen_fsm.start_link(FSM, [event_man: pid], [])
    stream = :fxml_stream.new(pid, :infinity, [])
    loop(conn, stream)
  end

  defp loop(conn, stream) do
    case Egapp.Server.recv(conn) do
      {:ok, packet} ->
        :fxml_stream.parse(stream, packet)
      {:error, :closed} -> exit(:normal)
      _ -> raise("recv read")
    end
    loop(conn, stream)
  end
end
