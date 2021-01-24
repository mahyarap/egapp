defmodule Egapp.WSHandler do
  @behaviour :cowboy_websocket

  def init(request, _state) do
    {:cowboy_websocket, request, %{}}
  end

  def websocket_init(state) do
    opts = [mod: Kernel, conn: self()]
    {:ok, pid} = Egapp.Parser.start_link(Egapp.Parser.WebsocketXML, opts)
    state = Map.put(state, :parser_pid, pid)
    {:ok, state}
  end

  def websocket_handle({:text, frame}, state) do
    Egapp.Parser.parse(state.parser_pid, frame)
    {:ok, state}
  end

  def websocket_info(info, state) do
    {:reply, {:text, info}, state}
  end
end
