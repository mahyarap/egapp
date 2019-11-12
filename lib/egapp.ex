defmodule Egapp do
  use Application

  def start(_type, _args) do
    children = [
      # Pass the parser to the server
      {Egapp.Server, [parser: Egapp.Parser.XML]},
      {Task.Supervisor, name: Egapp.ConnectionSupervisor}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Egapp.Supervisor)
  end
end
