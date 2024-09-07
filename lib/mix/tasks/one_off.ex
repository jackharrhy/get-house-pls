defmodule Mix.Tasks.OneOff do
  use Mix.Task

  @impl Mix.Task
  @requirements ["app.start"]
  def run(_args) do
    House.Checker.check() |> IO.inspect()
  end
end
