ExUnit.start()
{:ok, _pid} = Egapp.Repo.start_link()
Ecto.Adapters.SQL.Sandbox.mode(Egapp.Repo, :manual)
