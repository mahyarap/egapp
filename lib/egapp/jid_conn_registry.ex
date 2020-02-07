defmodule Egapp.JidConnRegistry do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    :ets.new(__MODULE__, [:set, :named_table, :public])
    {:ok, %{}}
  end

  def get(key) do
    case :ets.lookup(__MODULE__, key) do
      [{^key, value}] -> value
      [] -> nil
    end
  end

  def put(key, value) do
    :ets.insert(__MODULE__, {key, value})
  end

  def match_one(key_pattern) do
    case :ets.match_object(__MODULE__, {key_pattern, :_}) do
      [{key, value}] -> {key, value}
      [] -> nil
    end
  end

  def list do
    :ets.match(__MODULE__, :"$1")
  end
end
