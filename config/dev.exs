import Config

config :logger,
  backends: [:console]

config :egapp, Egapp.Repo,
  database: "egapp",
  username: "egapp",
  password: "pass",
  hostname: "localhost"

config :egapp,
  listen: 5222
