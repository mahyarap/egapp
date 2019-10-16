defmodule Egapp.Parser do
  def parse(conn) do
    # {:ok, pid} = :gen_event.start_link()
    # :gen_event.add_handler(pid, Egapp.Parser.EventManager, to: conn, via: {Egapp.Server, :send})
    {:ok, pid} = GenServer.start_link(Egapp.Parser.EventManager, [to: conn, mod: Egapp.Server])
    {:ok, pid} = :gen_fsm.start_link(Egapp.Parser.FSM, [event_man: pid], [])
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
