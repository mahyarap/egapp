import Config

config :egapp, Egapp.Repo,
  database: "egapp_test",
  username: "egapp",
  password: "pass",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

config :egapp,
  address: "127.0.0.1",
  port: 0

config :logger,
  level: :warn,
  backends: [:console],
  handle_otp_reports: true,
  handle_sasl_reports: false
