defmodule Mix.Tasks.TestSendLatest do
  use Mix.Task

  @impl Mix.Task
  @requirements ["app.start"]
  def run(_args) do
    House.Checker.test_send_latest() |> IO.inspect()
  end
end
