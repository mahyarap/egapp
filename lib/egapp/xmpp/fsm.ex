defmodule Egapp.XMPP.FSM do
  alias Egapp.XMPP.Stream
  alias Egapp.XMPP.Stanza

  @behaviour :gen_statem

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  @impl true
  def callback_mode, do: :state_functions

  @impl true
  def init(args) do
    init_state = Keyword.get(args, :init_state, :stream_init)

    state = %{
      mod: Keyword.fetch!(args, :mod),
      to: Keyword.fetch!(args, :to),
      client: %{
        is_authenticated: false
      }
    }

    {:ok, init_state, state}
  end

  def start_link(args, opts \\ []) do
    :gen_statem.start_link(__MODULE__, args, opts)
  end

  def stream_init(
        {:call, from},
        {"stream:stream", attrs},
        %{client: %{is_authenticated: false}} = state
      ) do
    {status, resp} = Stream.stream(attrs, state)
    apply(state.mod, :send, [state.to, resp])

    case status do
      :ok -> {:next_state, :auth, state, {:reply, from, :continue}}
      :error -> {:stop_and_reply, :normal, {:reply, from, :stop}, state}
    end
  end

  def stream_init(
        {:call, from},
        {"stream:stream", attrs},
        %{client: %{is_authenticated: true}} = state
      ) do
    {status, resp} = Stream.stream(attrs, state)
    apply(state.mod, :send, [state.to, resp])

    case status do
      :ok -> {:next_state, :bind, state, {:reply, from, :continue}}
      :error -> {:stop, :normal, {:reply, from, :stop}, state}
    end
  end

  def stream_init({:call, from}, :end, state) do
    apply(state.mod, :send, [state.to, Stream.stream_end()])
    {:stop_and_reply, :normal, {:reply, from, :stop}}
  end

  def stream_init({:call, from}, {:error, error}, state) do
    resp =
      case error do
        {2, "syntax error"} ->
          Stream.error(:bad_format, %{}, state)

        {4, "not well-formed (invalid token)"} ->
          Stream.error(:not_well_formed, %{}, state)

        {7, "mismatched tag"} ->
          Stream.error(:bad_format, %{}, state)

        {27, "unbound prefix"} ->
          Stream.error(:not_well_formed, %{}, state)

        {8, "duplicate attribute"} ->
          Stream.error(:not_well_formed, %{}, state)

        _ ->
          raise "should not get here"
      end

    apply(state.mod, :send, [state.to, resp])
    {:stop_and_reply, :normal, {:reply, from, :stop}, state}
  end

  def stream_init({:call, from}, {_tag_name, attrs}, state) do
    resp = Stream.error(:not_well_formed, attrs, state, stream_header: true)
    apply(state.mod, :send, [state.to, resp])
    {:stop_and_reply, :normal, {:reply, from, :stop}, state}
  end

  def auth({:call, from}, {"auth", attrs, data}, state) do
    {next_state, action, resp, state} =
      case Stream.auth(attrs, data, state) do
        {:ok, resp, state} -> {:stream_init, :reset, resp, state}
        {:retry, resp, state} -> {:auth, :continue, resp, state}
        {:error, resp, state} -> {nil, :stop, resp, state}
      end

    apply(state.mod, :send, [state.to, resp])

    if next_state do
      {:next_state, next_state, state, {:reply, from, action}}
    else
      {:stop_and_reply, :noraml, {:reply, from, action}, state}
    end
  end

  def auth({:call, from}, :end, state) do
    apply(state.mod, :send, [state.to, Stream.stream_end()])
    {:stop_and_reply, :normal, {:reply, from, :stop}}
  end

  def bind({:call, from}, {"iq", attrs, [{:xmlel, "bind", child_attrs, child_data}]}, state) do
    child_node = {"bind", to_map(child_attrs), child_data}
    {status, resp} = Stanza.iq(attrs, child_node, state)
    apply(state.mod, :send, [state.to, resp])

    case status do
      :ok -> {:next_state, :stanza, state, {:reply, from, :continue}}
      :error -> {:stop_and_reply, :normal, {:reply, from, :stop}, state}
    end
  end

  def bind({:call, from}, {_tag_name, attrs, _data}, state) do
    resp = Stream.error(:not_authorized, attrs, state)
    apply(state.mod, :send, [state.to, resp])
    {:stop_and_reply, :normal, {:reply, from, :stop}, state}
  end

  def bind({:call, from}, :end, state) do
    apply(state.mod, :send, [state.to, Stream.stream_end()])
    {:stop_and_reply, :normal, {:reply, from, :stop}}
  end

  def stanza({:call, from}, {"iq", attrs, data}, state) do
    child_node =
      case data do
        [{:xmlel, tag_name, child_attrs, child_data}] ->
          {tag_name, to_map(child_attrs), child_data}
      end

    {status, resp} = Stanza.iq(attrs, child_node, state)
    apply(state.mod, :send, [state.to, resp])

    case status do
      :ok -> {:next_state, :stanza, state, {:reply, from, :continue}}
      :error -> {:stop, :normal, state, {:reply, from, :stop}}
    end
  end

  def stanza({:call, from}, {"presence", attrs, data}, state) do
    contacts = Stanza.presence(attrs, data, state)
    for {conn, resp} <- contacts, do: apply(state.mod, :send, [conn, resp])
    {:next_state, :stanza, state, {:reply, from, :continue}}
  end

  def stanza({:call, from}, {"message", attrs, data}, state) do
    children =
      data
      |> Enum.map(fn child ->
        {:xmlel, tag_name, attrs, data} = child
        {tag_name, to_map(attrs), data}
      end)

    {:ok, {to, resp}} = Stanza.message(attrs, children, state)
    apply(state.mod, :send, [to, resp])
    {:next_state, :stanza, state, {:reply, from, :continue}}
  end

  def stanza({:call, from}, :end, state) do
    apply(state.mod, :send, [state.to, Stream.stream_end()])
    {:stop_and_reply, :normal, {:reply, from, :stop}}
  end

  defp to_map(attrs) do
    Enum.into(attrs, %{})
  end
end
