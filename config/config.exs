import Config

config :egapp,
  ecto_repos: [Egapp.Repo],
  address: "0.0.0.0",
  port: 5222,
  domain_name: "egapp.im",
  services: [
    Egapp.XMPP.Server,
    Egapp.XMPP.Conference
  ],
  sasl_mechanisms: [
    Egapp.SASL.Plain,
    Egapp.SASL.Digest
  ]

import_config "#{Mix.env()}.exs"
