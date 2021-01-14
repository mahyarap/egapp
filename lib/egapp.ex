defmodule Egapp do
  @moduledoc """
  The entry point for Egapp.
  """
  use Application

  def start(_type, _args) do
    children = [
      {Egapp.Repo, []},
      {Egapp.MucRegistry, []},
      {Egapp.JidConnRegistry, []},
      {Task.Supervisor, name: Egapp.ConnectionSupervisor},
      {Egapp.Server, []},
      Plug.Cowboy.child_spec(
        scheme: :http,
        plug: Egapp.MyAss,
        options: [
          dispatch: dispatch(),
          port: 8085
        ]
      ),
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Egapp.Supervisor)
  end

  defp dispatch do
    [
      {:_, [
        {"/ws", Egapp.WSHandler, []},
        {:_, Plug.Cowboy.Handler, {Egapp.MyAss, []}}
      ]}
    ]
  end
end
