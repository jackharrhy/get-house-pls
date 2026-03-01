defmodule House.Cookie do
  @moduledoc """
  Manages Incapsula/Imperva bot-detection cookies for realtor.ca API access.

  Launches real Chrome via a Node.js script to solve the JavaScript challenge,
  extracts the cookies (including the critical `reese84` token), and caches them.
  """

  require Logger

  @cookie_timeout_ms 60_000

  @doc """
  Returns a valid cookie string for the realtor.ca API.
  Launches Chrome to solve the Incapsula challenge and extract cookies.
  """
  def fetch_cookies do
    script = script_path()
    Logger.info("Fetching cookies via Chrome (#{script})...")

    port =
      Port.open({:spawn_executable, System.find_executable("node")}, [
        :binary,
        :exit_status,
        args: [script]
      ])

    collect_port_output(port, "", @cookie_timeout_ms)
  end

  defp collect_port_output(port, acc, timeout) do
    receive do
      {^port, {:data, data}} ->
        collect_port_output(port, acc <> data, timeout)

      {^port, {:exit_status, 0}} ->
        # Take only the last non-empty line — cookie script writes the cookie
        # string to stdout, but stray output (e.g. from child processes) could
        # leak in on earlier lines.
        cookies =
          acc
          |> String.split("\n")
          |> Enum.map(&String.trim/1)
          |> Enum.filter(&(&1 != ""))
          |> List.last("")

        Logger.info("Successfully obtained cookies (#{String.length(cookies)} chars)")
        {:ok, cookies}

      {^port, {:exit_status, code}} ->
        Logger.error("Cookie script failed (exit #{code}): #{acc}")
        {:error, :cookie_fetch_failed}
    after
      timeout ->
        Port.close(port)
        Logger.error("Cookie script timed out after #{timeout}ms")
        {:error, :cookie_timeout}
    end
  end

  defp script_path do
    candidates = [
      # Dev: relative to project root
      "scripts/get_cookies.mjs",
      # Release: scripts/ is copied alongside the release in /app
      Path.join(Application.app_dir(:house), "../../scripts/get_cookies.mjs"),
      # Release: fallback absolute path (matches Dockerfile COPY destination)
      "/app/scripts/get_cookies.mjs"
    ]

    Enum.find(candidates, &File.exists?/1) ||
      raise "Cookie script not found. Searched: #{inspect(candidates)}"
  end
end
