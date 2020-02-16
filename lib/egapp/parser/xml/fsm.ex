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
    parser = Keyword.fetch!(args, :parser)
    xmpp_fsm = Keyword.fetch!(args, :xmpp_fsm)

    state = %{
      parser: parser,
      xmpp_fsm: xmpp_fsm
    }

    {:ok, :xml_stream_start, state}
  end

  @impl true
  def handle_info(info, state, data) do
    Logger.debug("#{inspect({info, state, data})}")
  end

  @impl true
  def handle_event({:xmlstreamcdata, data}, current_state, state_data) do
    # TODO
    Logger.debug("#{inspect({:xml_stream_cdata, data, current_state, state_data})}")
    {:next_state, current_state, state_data}
  end

  @impl true
  def handle_sync_event(a, b, c, d) do
    Logger.debug("#{inspect({a, b, c, d})}")
    {a, b, c, d}
  end

  def xml_stream_start({:xmlstreamstart, tag_name, attrs}, state) do
    Logger.debug(
      "state=xml_stream_start event=xmlstreamstart tag_name=#{tag_name} attrs=#{inspect(attrs)}"
    )

    case :gen_statem.call(state.xmpp_fsm, {tag_name, to_map(attrs)}) do
      :continue -> {:next_state, :xml_stream_element, state}
      :stop -> {:stop, :normal, state}
    end
  end

  def xml_stream_start({:xmlstreamerror, error}, state) do
    Logger.debug("state=xml_stream_start event=xmlstreamerror error=#{inspect(error)}")
    :gen_statem.call(state.xmpp_fsm, {:error, error})
    {:stop, :normal, state}
  end

  def xml_stream_element({:xmlstreamelement, {:xmlel, child, attrs, data}}, state) do
    Logger.debug(
      "state=xml_stream_element event=xmlstreamelement tag_name=#{child} attrs=#{inspect(attrs)} data=#{
        inspect(data)
      }"
    )

    next_state =
      case :gen_statem.call(state.xmpp_fsm, {child, to_map(attrs), remove_whitespace(data)}) do
        :reset ->
          :ok = Egapp.Parser.XML.reset(state.parser)
          :xml_stream_start

        _ ->
          :xml_stream_element
      end

    {:next_state, next_state, state}
  end

  def xml_stream_element({:xmlstreamerror, error}, state) do
    Logger.debug("state=xml_stream_start event=xmlstreamerror error=#{inspect(error)}")
    :gen_statem.call(state.xmpp_fsm, {:error, error})
    {:stop, :normal, state}
  end

  def xml_stream_element({:xmlstreamend, _tag_name}, state) do
    :gen_statem.call(state.xmpp_fsm, :end)
    {:stop, :normal, state}
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
    Enum.reverse(result)
  end

  defp to_map(attrs) do
    Enum.into(attrs, %{})
  end
end
