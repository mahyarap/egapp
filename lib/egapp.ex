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
      {Egapp.Server, parser: Egapp.Parser.XML}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Egapp.Supervisor)
  end
end
