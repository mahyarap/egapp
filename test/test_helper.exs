ExUnit.start()
# TODO: This does not look right. Any better way?
Egapp.Repo.start_link()
Ecto.Adapters.SQL.Sandbox.mode(Egapp.Repo, :manual)
