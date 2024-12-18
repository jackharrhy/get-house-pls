defmodule House.Bot.Utils do
  def format_price(price) when is_integer(price) do
    price
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end

  def format_price(price), do: price
end
