defmodule House.Bot do
  alias House.Bot.Telegram
  alias House.Bot.Discord

  def send_house_details(house_data) do
    {:ok, _} = Telegram.send_house_details(house_data)
    {:ok, _} = Discord.send_house_details(house_data)

    :ok
  end
end
