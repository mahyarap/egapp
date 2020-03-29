defmodule Egapp.Parser do
  use GenServer

  @callback init(init_args :: term) :: {:ok, state} when state: term

  @callback handle_parse(data :: term, state :: term) ::
              {:noreply, new_state}
              | {:stop, reason :: term, new_state}
            when new_state: term

  @callback handle_reset(state :: term) ::
              {:reply, reply, new_state}
              | {:stop, reason, new_state}
            when reply: term, new_state: term, reason: term

  @callback handle_info(msg :: :timeout | term, state :: term) ::
              {:noreply, new_state}
              | {:stop, reason :: term, new_state}
            when new_state: term

  @optional_callbacks handle_reset: 1, handle_info: 2

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      @behaviour Egapp.Parser

      def child_spec(init_args) do
        default = %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [init_args]}
        }

        Supervisor.child_spec(default, unquote(Macro.escape(opts)))
      end

      defoverridable child_spec: 1
    end
  end

  def start_link(parser, args, opts \\ []) do
    args = Keyword.put(args, :parser, parser)
    GenServer.start_link(__MODULE__, args, opts)
  end

  def parse(pid, data) do
    GenServer.cast(pid, {:parse, data})
  end

  def reset(pid) do
    GenServer.call(pid, :reset)
  end

  @impl true
  def init(args) do
    {parser, args} = Keyword.pop(args, :parser)
    {:ok, state} = parser.init(args)
    {:ok, {parser, state}}
  end

  @impl true
  def handle_cast({:parse, data}, {parser, state}) do
    case parser.handle_parse(data, state) do
      {:noreply, new_state} -> {:noreply, {parser, new_state}}
      {:stop, reason, new_state} -> {:stop, reason, {parser, new_state}}
    end
  end

  @impl true
  def handle_call(:reset, _from, {parser, state}) do
    case parser.handle_reset(state) do
      {:reply, reply, new_state} -> {:reply, reply, {parser, new_state}}
      {:stop, reason, new_state} -> {:stop, reason, {parser, new_state}}
    end
  end
end
