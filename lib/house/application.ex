defmodule House.Application do
  use Application

  require Logger

  def start(_type, _args) do
    children = [
      House.Repo
    ]

    children =
      if Application.get_env(:house, :env) == :prod do
        Logger.info("Starting scheduler")
        children ++ [House.Scheduler]
      else
        children
      end

    opts = [strategy: :one_for_one, name: House.Supervisor]
    Logger.info("Starting root supervisor")
    Supervisor.start_link(children, opts)
  end
end
