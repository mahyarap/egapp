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
    state = %{
      mod: Keyword.get(args, :mod, Egapp.Server),
      to: Keyword.fetch!(args, :to),
      sasl_mechanisms: Keyword.get(args, :sasl_mechanisms),
      jid_conn_registry: Keyword.get(args, :jid_conn_registry),
      client: %{
        is_authenticated: false
      }
    }

    {:ok, :stream_init, state}
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
      :error -> {:stop_and_reply, :normal, {:reply, from, :stop}, state}
    end
  end

  def stream_init({:call, from}, {:error, error}, state) do
    handle_syntax_error(error, from, state)
  end

  def stream_init({:call, from}, {_tag_name, attrs}, state) do
    resp =
      Stream.not_well_formed_error()
      |> Stream.stream_template(Stream.build_stream_attrs(attrs, state))
      |> :xmerl.export_simple_element(:xmerl_xml)

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

  def auth({:call, from}, {:error, error}, state) do
    handle_syntax_error(error, from, state)
  end

  def auth({:call, from}, {_tag_name, _attrs, _data}, state) do
    resp =
      Stream.not_well_formed_error()
      |> :xmerl.export_simple_element(:xmerl_xml)

    apply(state.mod, :send, [state.to, resp])
    {:stop_and_reply, :normal, {:reply, from, :stop}, state}
  end

  def bind(
        {:call, from},
        {"iq", attrs, [{"bind", _child_attrs, _child_data} = child_node]},
        state
      ) do
    {status, resp} = Stanza.iq(attrs, child_node, state)

    Enum.each(resp, fn {conn, content} ->
      apply(state.mod, :send, [conn, content])
    end)

    case status do
      :ok -> {:next_state, :stanza, state, {:reply, from, :continue}}
      :error -> {:stop_and_reply, :normal, {:reply, from, :stop}, state}
    end
  end

  def bind({:call, from}, {:error, error}, state) do
    handle_syntax_error(error, from, state)
  end

  def bind({:call, from}, {_tag_name, attrs, _data}, state) do
    resp =
      Stream.not_authorized_error()
      |> Stream.stream_template(Stream.build_stream_attrs(attrs, state))
      |> :xmerl.export_simple_element(:xmerl_xml)

    apply(state.mod, :send, [state.to, resp])
    {:stop_and_reply, :normal, {:reply, from, :stop}, state}
  end

  def bind({:call, from}, :end, state) do
    apply(state.mod, :send, [state.to, Stream.stream_end()])
    {:stop_and_reply, :normal, {:reply, from, :stop}}
  end

  def stanza({:call, from}, {"iq", attrs, [data]}, state) do
    {status, resp} = Stanza.iq(attrs, data, state)

    Enum.each(resp, fn {conn, content} ->
      apply(state.mod, :send, [conn, content])
    end)

    case status do
      :ok -> {:next_state, :stanza, state, {:reply, from, :continue}}
      :error -> {:stop_and_reply, :normal, {:reply, from, :stop}, state}
    end
  end

  def stanza({:call, from}, {"presence", attrs, data}, state) do
    Stanza.presence(attrs, data, state)
    |> Enum.each(fn {conn, resp} ->
      apply(state.mod, :send, [conn, resp])
    end)

    {:next_state, :stanza, state, {:reply, from, :continue}}
  end

  def stanza({:call, from}, {"message", attrs, data}, state) do
    {:ok, {to, resp}} = Stanza.message(attrs, data, state)
    apply(state.mod, :send, [to, resp])
    {:next_state, :stanza, state, {:reply, from, :continue}}
  end

  def stanza({:call, from}, {:error, error}, state) do
    handle_syntax_error(error, from, state)
  end

  def stanza({:call, from}, :end, state) do
    apply(state.mod, :send, [state.to, Stream.stream_end()])
    {:stop_and_reply, :normal, {:reply, from, :stop}}
  end

  def stanza({:call, from}, {_tag_name, attrs, _data}, state) do
    resp =
      Stream.not_authorized_error()
      |> Stream.stream_template(Stream.build_stream_attrs(attrs, state))
      |> :xmerl.export_simple_element(:xmerl_xml)

    apply(state.mod, :send, [state.to, resp])
    {:stop_and_reply, :normal, {:reply, from, :stop}, state}
  end

  defp handle_syntax_error(error, from, state) do
    error =
      case error do
        {2, "syntax error"} ->
          Stream.bad_format_error()

        {4, "not well-formed (invalid token)"} ->
          Stream.not_well_formed_error()

        {7, "mismatched tag"} ->
          Stream.bad_format_error()

        {27, "unbound prefix"} ->
          Stream.not_well_formed_error()

        {8, "duplicate attribute"} ->
          Stream.not_well_formed_error()

        _ ->
          raise "should not get here"
      end

    resp =
      error
      |> Stream.stream_template(Stream.build_stream_attrs(%{}, state))
      |> :xmerl.export_simple_element(:xmerl_xml)

    apply(state.mod, :send, [state.to, resp])
    {:stop_and_reply, :normal, {:reply, from, :stop}, state}
  end
end
