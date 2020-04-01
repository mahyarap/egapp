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

  def start_link(args, opts \\ []) do
    :gen_fsm.start_link(__MODULE__, args, opts)
  end

  @impl true
  def init(args) do
    conn = Keyword.fetch!(args, :conn)
    parser = Keyword.fetch!(args, :parser)
    mod = Keyword.get(args, :mod, Egapp.Server)
    xmpp_fsm = Keyword.get(args, :xmpp_fsm, Egapp.XMPP.FSM)
    {:ok, pid} = xmpp_fsm.start_link(mod: mod, to: conn)

    state = %{
      parser: parser,
      xmpp_fsm: pid
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

    case :gen_statem.call(state.xmpp_fsm, {child, to_map(attrs), neutralize(data)}) do
      :reset ->
        :ok = Egapp.Parser.reset(state.parser)
        {:next_state, :xml_stream_start, state}

      :stop ->
        {:stop, :normal, state}

      _ ->
        {:next_state, :xml_stream_element, state}
    end
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
