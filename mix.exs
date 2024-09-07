defmodule House.MixProject do
  use Mix.Project

  def project do
    [
      app: :house,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {House.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp deps do
    [
      {:ecto_sql, "~> 3.12"},
      {:ecto_sqlite3, "~> 0.17.2"},
      {:quantum, "~> 3.0"},
      {:req, "~> 0.5.0"},
      {:telegram, github: "visciang/telegram", tag: "1.2.1"},
      {:dotenvy, "~> 0.8.0"}
    ]
  end
end
