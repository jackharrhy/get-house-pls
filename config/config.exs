import Config

config :house, House.Repo,
  database: "house.db",
  pool_size: 5

config :house,
  ecto_repos: [House.Repo]

config :house, House.Scheduler,
  jobs: [
    {"* * * * *", {House.Fetch, :test, []}}
  ]
