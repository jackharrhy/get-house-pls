import Config
import Dotenvy

source!([".env", System.get_env()])

config :house, House.Repo, database: env!("HOUSE_DATABASE", :string, "house.db")

config :house, :telegram_enabled, env!("HOUSE_TELEGRAM_ENABLED", :boolean, false)
config :house, :telegram_token, env!("HOUSE_TELEGRAM_TOKEN", :string, nil)
config :house, :telegram_chat_id, env!("HOUSE_TELEGRAM_CHAT_ID", :string, nil)

config :house, :discord_enabled, env!("HOUSE_DISCORD_ENABLED", :boolean, false)
config :house, :discord_channel_id, env!("HOUSE_DISCORD_CHANNEL_ID", :integer, nil)

config :nostrum,
  token: env!("HOUSE_DISCORD_TOKEN", :string, nil),
  youtubedl: nil,
  streamlink: nil,
  gateway_intents: []

config :house,
       :realtor_post_config,
       env!("HOUSE_REALTOR_POST_CONFIG", :string!)
       |> String.split(",")
       |> Enum.map(fn x ->
         [key, value] = String.split(x, ":")
         key = key |> String.trim() |> String.to_atom()
         value = value |> String.trim()

         value =
           if String.contains?(value, ".") do
             case Float.parse(value) do
               {float, _} -> float
               :error -> value
             end
           else
             case Integer.parse(value) do
               {int, _} -> int
               :error -> value
             end
           end

         {key, value}
       end)
       |> Keyword.new()
