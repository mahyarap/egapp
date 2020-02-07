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
  address: "0.0.0.0",
  port: 5222,
  domain_name: "egapp.im"
