defmodule House.Fetch do
  require Logger

  def fetch_data do
    form_params =
      [
        Sort: "6-D",
        PropertyTypeGroupID: 1,
        TransactionTypeId: 2,
        PropertySearchTypeId: 0,
        Currency: "CAD",
        IncludeHiddenListings: false,
        RecordsPerPage: 12,
        ApplicationId: 1,
        CultureId: 1,
        Version: "7.0",
        CurrentPage: 1
      ] ++ Application.fetch_env!(:house, :realtor_post_config)

    # Build URL-encoded form body string for the Node script
    form_body =
      form_params
      |> Enum.map(fn {k, v} -> "#{k}=#{URI.encode_www_form(to_string(v))}" end)
      |> Enum.join("&")

    {:ok, json} = House.Browser.fetch_listings(form_body)
    Jason.decode!(json)
  end

  def format_data(body) do
    case body do
      %{"Results" => results} when is_list(results) ->
        format_results(results)

      other ->
        Logger.error("Unexpected API response format: #{inspect(other, limit: 200)}")
        []
    end
  end

  defp format_results(results) do
    for result <- results do
      property = result["Property"]
      address = property["Address"]
      photo = property["Photo"]
      building = result["Building"]

      price = property["PriceUnformattedValue"]

      price = if is_nil(price), do: property["Price"], else: price |> String.to_integer()

      bedrooms =
        if building["Bedrooms"] do
          case Integer.parse(building["Bedrooms"]) do
            {int, _} -> int
            :error -> nil
          end
        else
          nil
        end

      bathrooms =
        if building["Bathrooms"] do
          case Integer.parse(building["Bathrooms"]) do
            {int, _} -> int
            :error -> nil
          end
        else
          nil
        end

      %{
        url: "https://realtor.ca#{result["RelativeDetailsURL"]}",
        mls: result["MlsNumber"] |> String.to_integer(),
        price: price,
        address: address["AddressText"] |> String.split("|"),
        lat: address["Latitude"],
        lon: address["Longitude"],
        photos: photo |> Enum.map(& &1["HighResPath"]),
        time_on_realtor: result["TimeOnRealtor"],
        bedrooms: bedrooms,
        bathrooms: bathrooms
      }
    end
  end
end
