defmodule Egapp.Parser.WebsocketXML do
  use Egapp.Parser

  @impl true
  def init(args) do
    conn = Keyword.fetch!(args, :conn)
    mod = Keyword.get(args, :mod, Egapp.Server)
    opts = [mod: mod, conn: conn, parser: self(), ws: true]
    {:ok, xmpp_fsm} = Egapp.XMPP.FSM.start_link(mod: mod, to: conn, ws: true)
    Process.monitor(xmpp_fsm)

    {:ok, %{xmpp_fsm: xmpp_fsm, conn: conn}}
  end

  @impl true
  def handle_reset(state) do
    {:reply, :ok, state}
  end

  @impl true
  def handle_parse(data, state) do
    {:xmlel, tag_name, attrs, data} = :fxml_stream.parse_element(data)
    :gen_statem.call(state.xmpp_fsm, {tag_name, to_map(attrs), neutralize(data)})
    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    case msg do
      {:DOWN, _, :process, _, _} -> :gen_tcp.close(state.conn)
    end

    {:stop, :normal, state}
  end

  defp to_map(attrs) do
    Enum.into(attrs, %{})
  end

  defp neutralize([h | t]) do
    maped = neutralize(h)
    if maped, do: [maped | neutralize(t)], else: neutralize(t)
  end

  defp neutralize({:xmlel, tag_name, attrs, children}) do
    {tag_name, to_map(attrs), neutralize(children)}
  end

  defp neutralize({:xmlcdata, "\n"}), do: nil

  defp neutralize({:xmlcdata, content}), do: content

  defp neutralize([]), do: []
end

