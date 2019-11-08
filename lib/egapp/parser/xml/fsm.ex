defmodule Egapp.Parser.XML.FSM do
  require Logger

  @behaviour :gen_fsm

  @impl true
  def init(args) do
    event_man = Keyword.fetch!(args, :event_man)
    init_state = Keyword.get(args, :init_state, :begin)
    state = %{
      event_man: event_man,
    }
    {:ok, init_state, state}
  end

  @impl true
  def handle_info(info, state, data) do
    IO.inspect {info, state, data}
  end

  @impl true
  def handle_event({:xmlstreamcdata, data}, current_state, state_data) do
    # TODO
    Logger.debug("c2s: #{inspect {:xml_stream_cdata, data, current_state, state_data}}")
    {:next_state, current_state, state_data}
  end

  @impl true
  def handle_sync_event(a, b, c, d) do
    IO.inspect {a, b, c, d}
    {a, b, c, d}
  end

  defp to_map(attrs) do
    Enum.into(attrs, %{})
  end

  def begin({:xmlstreamstart, tag_name, attrs}, state) do
    Logger.debug("c2s: #{inspect {:begin, tag_name, attrs, state}}")
    GenServer.call(state.event_man, {tag_name, to_map(attrs)})
    {:next_state, :xml_stream_start, state}
  end

  def begin({:xmlstreamerror, error}, state) do
    IO.inspect {:xml_stream_error, error, state}
    GenServer.call(state.event_man, {"error:parsing", error})
    {:stop, :normal, state}
  end

  def xml_stream_start({:xmlstreamelement, tag_name, attrs}, state) do
    IO.inspect {:xml_stream_element, tag_name, attrs, state}
    {:next_state, :xml_stream_element, state}
  end

  def xml_stream_start({:xmlstreamelement, {:xmlel, child, attrs, data}}, state) do
    IO.inspect {:xml_stream_element, child, to_map(attrs), data, state}
    next_state =
      case GenServer.call(state.event_man, {child, to_map(attrs), data}) do
        :reset -> :begin
        _ -> :xml_stream_element
      end
    {:next_state, next_state, state}
  end

  def xml_stream_start({:xmlstreamend, tag_name}, state) do
    IO.inspect {:xml_stream_end, tag_name, state}
    # if tag_name == Egapp.Stack.pop(state).tag_name do
      # IO.puts "matched"
    # end
    {:next_state, :xml_stream_start, state}
  end

  def xml_stream_start({:xmlstreamerror, foo}, state) do
    IO.inspect {:xmlstreamerror, foo, state}
  end

  def xml_stream_end({:xmlstreamend, data}, state) do
    IO.inspect {:xml_end, data, state}
    {:next_state, :xml_stream_start, state}
  end

  def xml_stream_element({:xmlstreamcdata, data}, state) do
    IO.inspect {:xml_stream_cdata, data, state}
    {:next_state, :xml_stream_cdata, state}
  end

  def xml_stream_element({:xmlstreamelement, {:xmlel, child, attrs, data}}, state) do
    IO.inspect {:xml_stream_element, child, attrs, data, state}
    GenServer.call(state.event_man, {child, to_map(attrs), data})
    {:next_state, :xml_stream_element, state}
  end

  def xml_stream_element({:xmlstreamend, tag_name}, state) do
    IO.inspect {:xml_stream_end, tag_name, state}
    # if tag_name == Egapp.Stack.pop(state).tag_name do
      # IO.puts "matched"
      # Egapp.Stack.reset(state)
    # end
    GenServer.call(:event_man, :read)
    {:next_state, :begin, state}
  end

  def xml_stream_cdata({:xmlstreamelement, tag_name, attrs}, state) do
    IO.inspect {:xml_stream_element, tag_name, attrs, state}
    {:next_state, :xml_stream_element, state}
  end

  def xml_stream_cdata({:xmlstreamelement, tag_name}, state) do
    IO.inspect {:xml_stream_element, tag_name, state}
    {:next_state, :xml_stream_element, state}
  end
end

# defmodule Egapp.Stack do
#   use Agent

#   def start_link do
#     Agent.start_link(fn -> [] end)
#   end

#   def push(stack, el) do
#     Agent.update(stack, fn stack -> [el | stack] end)
#   end

#   def pop(stack) do
#     Agent.get_and_update(stack, fn stack -> {hd(stack), tl(stack)} end)
#   end

#   def top(stack) do
#     Agent.get(stack, &hd(&1))
#   end

#   def reset(stack) do
#     Agent.update(stack, fn _stack -> [] end)
#   end

#   def get(stack) do
#     Agent.get(stack, fn stack -> stack end)
#   end
# end
