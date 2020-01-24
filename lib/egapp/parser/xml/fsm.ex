defmodule Egapp.Parser.XML.FSM do
  require Logger

  @behaviour :gen_fsm

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  def start_link(args) do
    :gen_fsm.start_link(__MODULE__, args, [])
  end

  @impl true
  def init(args) do
    event_man = Keyword.fetch!(args, :event_man)
    init_state = Keyword.get(args, :init_state, :begin)

    state = %{
      event_man: event_man
    }

    {:ok, init_state, state}
  end

  @impl true
  def handle_info(info, state, data) do
    IO.inspect({info, state, data})
  end

  @impl true
  def handle_event({:xmlstreamcdata, data}, current_state, state_data) do
    # TODO
    Logger.debug("fsm: #{inspect({:xml_stream_cdata, data, current_state, state_data})}")
    {:next_state, current_state, state_data}
  end

  @impl true
  def handle_sync_event(a, b, c, d) do
    IO.inspect({a, b, c, d})
    {a, b, c, d}
  end

  defp to_map(attrs) do
    Enum.into(attrs, %{})
  end

  def begin({:xmlstreamstart, tag_name, attrs}, state) do
    Logger.debug("fsm: #{inspect({:begin, tag_name, attrs, state})}")

    case GenServer.call(state.event_man, {tag_name, to_map(attrs)}) do
      :continue -> {:next_state, :xml_stream_start, state}
      :stop -> {:stop, :normal, state}
    end
  end

  def begin({:xmlstreamerror, error}, state) do
    IO.inspect({:xml_stream_error, error, state})
    GenServer.call(state.event_man, {:error, error})
    {:stop, :normal, state}
  end

  def xml_stream_start({:xmlstreamelement, tag_name, attrs}, state) do
    IO.inspect({:xml_stream_element, tag_name, attrs, state})
    {:next_state, :xml_stream_element, state}
  end

  def xml_stream_start({:xmlstreamelement, {:xmlel, child, attrs, data}}, state) do
    IO.inspect({:xml_stream_element, child, to_map(attrs), data, state})

    next_state =
      case GenServer.call(state.event_man, {child, to_map(attrs), remove_whitespace(data)}) do
        :reset -> :begin
        _ -> :xml_stream_element
      end

    {:next_state, next_state, state}
  end

  def xml_stream_start({:xmlstreamend, tag_name}, state) do
    IO.inspect({:xml_stream_end, tag_name, state})
    {:next_state, :xml_stream_start, state}
  end

  def xml_stream_start({:xmlstreamerror, foo}, state) do
    IO.inspect({:xmlstreamerror, foo, state})
  end

  def xml_stream_end({:xmlstreamend, data}, state) do
    IO.inspect({:xml_end, data, state})
    {:next_state, :xml_stream_start, state}
  end

  def xml_stream_element({:xmlstreamcdata, data}, state) do
    IO.inspect({:xml_stream_cdata, data, state})
    {:next_state, :xml_stream_cdata, state}
  end

  def xml_stream_element({:xmlstreamelement, {:xmlel, child, attrs, data}}, state) do
    IO.inspect({:xml_stream_element, child, attrs, data, state})
    GenServer.call(state.event_man, {child, to_map(attrs), remove_whitespace(data)})
    {:next_state, :xml_stream_element, state}
  end

  def xml_stream_element({:xmlstreamend, _tag_name}, state) do
    GenServer.call(state.event_man, {"end"})
    {:stop, :normal, state}
  end

  def xml_stream_cdata({:xmlstreamelement, tag_name, attrs}, state) do
    IO.inspect({:xml_stream_element, tag_name, attrs, state})
    {:next_state, :xml_stream_element, state}
  end

  def xml_stream_cdata({:xmlstreamelement, tag_name}, state) do
    IO.inspect({:xml_stream_element, tag_name, state})
    {:next_state, :xml_stream_element, state}
  end

  defp remove_whitespace(data) do
    do_remove_whitespace(data, [])
  end

  defp do_remove_whitespace([h | t], result) when is_list(h) do
    do_remove_whitespace(t, [do_remove_whitespace(h, []) | result])
  end

  defp do_remove_whitespace([h | t], result) do
    case h do
      {:xmlcdata, "\n"} -> do_remove_whitespace(t, result)
      _ -> do_remove_whitespace(t, [h | result])
    end
  end

  defp do_remove_whitespace([], result) do
    result |> Enum.reverse()
  end
end
