defmodule House.Browser do
  @moduledoc """
  Fetches realtor.ca API data by launching real Chrome and intercepting the
  response via CDP.

  Incapsula validates cookies AND TLS fingerprint — we can't extract cookies
  and replay them with Elixir's HTTP client because it has a different TLS
  fingerprint. Instead, we let Chrome make the request itself (by navigating
  to a search URL) and intercept the JSON response via the CDP Network domain.
  """

  require Logger

  @doc """
  Runs the get_listings.mjs script with the given URL-encoded form body.
  Returns `{:ok, json_string}` or `{:error, reason}`.

  The script writes JSON to a temp file (not stdout) because Erlang Ports
  truncate stdout at 64KB. The script writes the file path to stdout instead.
  """
  def fetch_listings(form_body) when is_binary(form_body) do
    script = script_path()
    output_file = Path.join(System.tmp_dir!(), "house_listings_#{:rand.uniform(100_000)}.json")
    Logger.info("Fetching listings via Chrome (#{script})...")

    {output, exit_code} =
      System.cmd("node", [script, form_body, output_file], stderr_to_stdout: false)

    case exit_code do
      0 ->
        case File.read(output_file) do
          {:ok, json} ->
            File.rm(output_file)
            Logger.info("Chrome returned #{String.length(json)} chars of JSON")
            {:ok, json}

          {:error, reason} ->
            Logger.error("Could not read output file #{output_file}: #{inspect(reason)}")
            {:error, :browser_fetch_failed}
        end

      code ->
        Logger.error("Listings script failed (exit #{code}): #{String.slice(output, 0, 500)}")
        File.rm(output_file)
        {:error, :browser_fetch_failed}
    end
  end

  defp script_path do
    candidates = [
      # Dev: relative to project root
      "scripts/get_listings.mjs",
      # Release: scripts/ is copied alongside the release in /app
      Path.join(Application.app_dir(:house), "../../scripts/get_listings.mjs"),
      # Release: fallback absolute path (matches Dockerfile COPY destination)
      "/app/scripts/get_listings.mjs"
    ]

    Enum.find(candidates, &File.exists?/1) ||
      raise "Listings script not found. Searched: #{inspect(candidates)}"
  end
end
