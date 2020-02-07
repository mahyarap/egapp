import Config

config :egapp, Egapp.Repo,
  database: "egapp_test",
  username: "egapp",
  password: "pass",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

config :egapp,
  ecto_repos: [Egapp.Repo],
  address: "127.0.0.1",
  port: 0,
  domain_name: "egapp.im"

config :logger,
  backends: [:console],
  level: :warn
