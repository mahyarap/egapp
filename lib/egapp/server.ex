defmodule Egapp.Server do
  @moduledoc """
  A special process which acts as a TCP server/client.
  """
  alias Egapp.Config

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
    {:ok, spawn_link(__MODULE__, :serve, [args])}
  end

  def serve(args) do
    socket = listen(Config.get(:address), Config.get(:port))
    loop(socket, args)
  end

  defp loop(socket, args) do
    parser = Keyword.fetch!(args, :parser)
    conn = accept(socket)

    {:ok, _} =
      Task.Supervisor.start_child(Egapp.ConnectionSupervisor, fn ->
        {:ok, pid} = GenServer.start_link(parser, conn)
        :gen_tcp.controlling_process(conn, pid)
        recv_loop(conn, parser, pid)
      end)

    loop(socket, args)
  end

  defp recv_loop(conn, parser, pid) do
    case recv(conn) do
      {:ok, packet} ->
        parser.parse(pid, packet)
        recv_loop(conn, parser, pid)

      {:error, :closed} ->
        Process.exit(pid, :normal)

      _ ->
        IO.puts("GGGGGGGG")
    end
  end

  defp listen(address, port) do
    {:ok, address} =
      address
      |> String.to_charlist()
      |> :inet.parse_address()

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
      # Address to bind to
      ip: address,
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
