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

config :mnesia,
  # dir must be a charlist
  dir: '/tmp/mnesia'
