defmodule Egapp.MucRegistry do
  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    case :mnesia.create_schema([node()]) do
      :ok ->
        :mnesia.start()

        table_def = [
          attributes: [:name, :participants],
          disc_copies: [node()],
          type: :set
        ]

        :mnesia.create_table(:rooms, table_def)

      {:error, {_, {:already_exists, _}}} ->
        :mnesia.start()
    end

    {:ok, []}
  end
end
