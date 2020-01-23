import Config

config :egapp, Egapp.Repo,
  database: "egapp_test",
  username: "egapp",
  password: "pass",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

config :egapp,
  ecto_repos: [Egapp.Repo]

config :logger,
  backends: [:console],
  level: :warn
