import Config

config :house,
  ecto_repos: [House.Repo]

config :house, House.Scheduler,
  jobs: [
    {"0 */3 * * *", {House.Checker, :check, []}}
  ]

config :house, env: Mix.env()
