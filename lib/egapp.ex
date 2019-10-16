defmodule Egapp do
  use Application

  def start(_type, _args) do
    children = [
      {Egapp.Server, [Egapp.Parser, :parse]},
      {Task.Supervisor, name: Egapp.ParserSupervisor},
    ]
    Supervisor.start_link(children, strategy: :one_for_one, name: Egapp.Supervisor)
  end
end
