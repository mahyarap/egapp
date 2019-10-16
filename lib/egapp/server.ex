defmodule Egapp.Server do
  def child_spec(args) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [args]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  def start_link(args) do
    {:ok, spawn_link(fn -> serve(args) end)}
  end

  defp serve(args) do
    socket = listen(5222)
    loop(socket, args)
  end

  defp loop(socket, args) do
    [mod, func] = args
    conn = accept(socket)
    {:ok, pid} = Task.Supervisor.start_child(Egapp.ParserSupervisor, fn ->
      apply(mod, func, [conn])
    end)
    :gen_tcp.controlling_process(conn, pid)
    loop(socket, args)
  end

  defp listen(port) do
    conn_opts = [
      # Received Packet is delivered as a binary
      :binary,
      # No header is prepended to the packet (internal to erlang)
      packet: 0,
      # Everything received from the socket is sent as messages to the
      # receiving process
      active: false,
      # See https://stackoverflow.com/a/3233022/2641387
      reuseaddr: true,
      # See man 7 tcp (TCP_NODELAY)
      nodelay: true,
      keepalive: true,
    ]
    {:ok, socket} = :gen_tcp.listen(port, conn_opts)
    socket
  end

  defp accept(socket) do
    {:ok, conn} = :gen_tcp.accept(socket)
    conn
  end

  def send(conn, content) do
    :gen_tcp.send(conn, content)
  end

  def recv(conn) do
    :gen_tcp.recv(conn, 0)
  end
end
