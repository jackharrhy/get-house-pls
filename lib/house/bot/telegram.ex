defmodule House.Bot.Telegram do
  alias House.Bot.Utils

  require Logger

  def send_house_details(house_data) do
    if Application.fetch_env!(:house, :telegram_enabled) do
      {:ok, _} = resp = format_property_message(house_data) |> send_message()
      resp
    else
      Logger.info("Telegram is not enabled, skipping message")
      {:ok, :not_enabled}
    end
  end

  def send_message(text) do
    Telegram.Api.request(Application.fetch_env!(:house, :telegram_token), "sendMessage",
      chat_id: Application.fetch_env!(:house, :telegram_chat_id),
      text: text,
      parse_mode: "MarkdownV2"
    )
  end

  defp format_property_message(house_data) do
    address = house_data.address |> Enum.map(&escape_markdown_v2/1) |> Enum.join(", ")
    price = Utils.format_price(house_data.price)
    bedrooms = if house_data.bedrooms, do: house_data.bedrooms, else: "N/A"
    bathrooms = if house_data.bathrooms, do: house_data.bathrooms, else: "N/A"

    """
    🏠 New Property Listed\\!

    👉 MLS: #{house_data.mls}
    💰 Price: $#{price}
    🛏️ Bedrooms: #{bedrooms}
    🚿 Bathrooms: #{bathrooms}
    📍 Address: #{address}
    📅 Time on Realtor: #{house_data.time_on_realtor}
    🗺️ Location: #{escape_markdown_v2(house_data.lat)}, #{escape_markdown_v2(house_data.lon)}
    🖼️ Photos: #{Enum.at(house_data.photos, 0, "No photos available") |> escape_markdown_v2()}

    [Visit on Realtor](#{escape_markdown_v2(house_data.url)})
    """
  end

  defp escape_markdown_v2(text) do
    text
    |> String.replace(~r/([_*\[\]()~`>#+\-=|{}.!])/, "\\\\\\1")
  end
end
