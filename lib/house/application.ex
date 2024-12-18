defmodule House.Application do
  use Application

  require Logger

  defp setup_discord(children) do
    if Application.get_env(:house, :discord_enabled) do
      Logger.info("Starting Discord")
      children ++ [Nostrum.Application, House.Bot.Discord]
    else
      Logger.info("Not starting Discord, since it's not enabled")
      children
    end
  end

  defp setup_scheduler(children) do
    if Application.get_env(:house, :env) == :prod do
      Logger.info("Starting scheduler")
      children ++ [House.Scheduler]
    else
      Logger.info("Not starting scheduler, since we're not prod")
      children
    end
  end

  def start(_type, _args) do
    children =
      [House.Repo]
      |> setup_discord()
      |> setup_scheduler()

    opts = [strategy: :one_for_one, name: House.Supervisor]
    Logger.info("Starting root supervisor")
    res = Supervisor.start_link(children, opts)

    House.Checker.check()

    res
  end
end
