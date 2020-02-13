defmodule Egapp do
  use Application

  def start(_type, _args) do
    children = [
      {Egapp.Repo, []},
      {Egapp.JidConnRegistry, []},
      {Task.Supervisor, name: Egapp.ConnectionSupervisor},
      {Egapp.Server, parser: Egapp.Parser.XML}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Egapp.Supervisor)
  end
end
