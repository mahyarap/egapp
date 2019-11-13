import Config

config :logger,
  backends: [:console]

config :egapp, Egapp.Repo,
  database: "egapp",
  username: "user",
  password: "pass",
  hostname: "localhost"
