defmodule House.Checker do
  alias House.Fetch
  alias House.Bot
  alias House.Schema.House

  require Logger

  def check do
    for property <- Fetch.fetch_data() |> Fetch.format_data() do
      if House.exists?(property.mls) do
        Logger.info("House with MLS #{property.mls} already exists")
      else
        Logger.info("House with MLS #{property.mls} does not exist")
        Bot.send_house_details(property)
        House.insert_house(property)
      end
    end
  end
end
