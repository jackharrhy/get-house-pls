defmodule House.Bot do
  @chat_id Application.compile_env!(:house, :telegram_chat_id)
  @token Application.compile_env!(:house, :telegram_token)

  def send_message(text) do
    Telegram.Api.request(@token, "sendMessage", chat_id: @chat_id, text: text)
  end

  def send_house_details(house_data) do
    format_house_message(house_data)
  end

  defp format_house_message(house_data) do
    """
    🏠 New House Listed!

    MLS: #{house_data.mls}
    💰 Price: $#{format_price(house_data.price)}
    🛏️ Bedrooms: #{house_data.bedrooms}
    🚿 Bathrooms: #{house_data.bathrooms}
    📍 Address: #{Enum.join(house_data.address, ", ")}
    📅 Time on Realtor: #{house_data.time_on_realtor}
    🗺️ Location: #{house_data.lat}, #{house_data.lon}
    🖼️ Photos: #{Enum.at(house_data.photos, 0, "No photos available")}
    """
  end

  defp format_price(price) when is_integer(price) do
    price
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end

  defp format_price(price), do: price
end
