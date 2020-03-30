defmodule Egapp.JidConnRegistry do
  @moduledoc """
  A simple registry to store user's jid along its port

  A GenServer is only used to own the ETS table. All the functions in this
  module interface directly to the ETS functions. This way, we make sure
  messages are not serialized by the GenServer.
  """
  @callback match(key :: term) :: [tuple]
  @callback put(key :: term, val :: term) :: {:ok, tuple} | {:error, term}

  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    :ets.new(__MODULE__, [:bag, :named_table, :public])
    {:ok, %{}}
  end

  def match(key) do
    :ets.lookup(__MODULE__, key)
    |> Enum.map(fn {_bare_jid, jid, conn} -> {jid, conn} end)
  end

  def put(key, {jid, conn} = _value) do
    :ets.insert(__MODULE__, {key, jid, conn})
  end

  def list do
    :ets.match(__MODULE__, :"$1")
  end
end
