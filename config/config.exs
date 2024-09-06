import Config

config :house, House.Repo,
  database: "house.db",
  pool_size: 5,
  log: false

config :house,
  ecto_repos: [House.Repo]

config :house, House.Scheduler,
  jobs: [
    {"* * * * *", {House.Checker, :check, []}}
  ]

import_config "#{Mix.env()}.secret.exs"
