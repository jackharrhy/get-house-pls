defmodule House.Application do
  use Application

  def start(_type, _args) do
    children = [
      House.Repo
    ]

    children =
      if Application.get_env(:house, :env) == :prod do
        children ++ [House.Scheduler]
      else
        children
      end

    opts = [strategy: :one_for_one, name: House.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
