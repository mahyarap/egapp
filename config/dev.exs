import Config

config :logger,
  backends: [:console],
  handle_otp_reports: true,
  handle_sasl_reports: true

config :egapp, Egapp.Repo,
  database: "egapp",
  username: "egapp",
  password: "pass",
  hostname: "localhost"

config :egapp,
  listen: 5222
