defmodule House.Checker do
  alias House.Fetch
  alias House.Bot
  alias House.Schema.House

  require Logger

  def check do
    properties = Fetch.fetch_data() |> Fetch.format_data()

    if length(properties) == 0 do
      Logger.warning("No properties found")
      :no_properties
    else
      Logger.info("Found #{length(properties)} properties")

      for property <- properties do
        if House.exists?(property.mls) do
          Logger.info("House with MLS #{property.mls} already exists")
          {:ok, _} = House.update_house(property)
          {:already_exists, property.mls}
        else
          Logger.info("House with MLS #{property.mls} does not exist")
          {:ok, _} = House.insert_house(property)
          :ok = Bot.send_house_details(property)
          {:new_house, property.mls}
        end
      end
    end
  end

  def test_send_latest do
    Fetch.fetch_data() |> Fetch.format_data() |> Enum.at(1) |> Bot.send_house_details()
  end
end
