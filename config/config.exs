import Config

config :hl7_poc,
  database_url: "postgres://demo:demo@db:5432/hl7_demo"

config :hl7_poc, Hl7Poc.Repo,
  database: "hl7_demo",
  username: "demo",
  password: "demo",
  hostname: "db",
  port: 5432,
  pool_size: 10
