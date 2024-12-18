defmodule House.Bot.Discord do
  use Nostrum.Consumer

  alias Nostrum.Api
  import Nostrum.Struct.Embed
  alias House.Bot.Utils

  require Logger

  def send_house_details(house_data) do
    if Application.fetch_env!(:house, :discord_enabled) do
      embed = format_property_embed(house_data)

      Api.create_message(
        Application.fetch_env!(:house, :discord_channel_id),
        embed: embed
      )
    else
      Logger.info("Discord is not enabled, skipping message")
      {:ok, :not_enabled}
    end
  end

  def format_property_embed(house_data) do
    address = house_data.address |> Enum.join(", ")
    price = Utils.format_price(house_data.price)
    bedrooms = if house_data.bedrooms, do: house_data.bedrooms, else: "N/A"
    bathrooms = if house_data.bathrooms, do: house_data.bathrooms, else: "N/A"

    %Nostrum.Struct.Embed{}
    |> put_title("$#{price} - #{address}")
    |> put_description("MLS: #{house_data.mls}\nPosted #{house_data.time_on_realtor}")
    |> put_url(house_data.url)
    |> put_field("Bedrooms", bedrooms)
    |> put_field("Bathrooms", bathrooms)
    |> put_field("Location", "#{house_data.lat}, #{house_data.lon}")
    |> put_image(house_data.photos |> List.first())
  end

  def handle_event({:MESSAGE_CREATE, _msg, _ws_state}) do
    :ignore
  end
end
