defmodule House.Fetch do
  require Logger

  def fetch_data do
    {:ok, cookies} = House.Cookie.fetch_cookies()

    form =
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

    Req.post!(
      "https://api2.realtor.ca/Listing.svc/PropertySearch_Post",
      headers: [
        {"user-agent",
         "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36"},
        {"referer", "https://www.realtor.ca/"},
        {"origin", "https://www.realtor.ca"},
        {"accept", "*/*"},
        {"accept-language", "en-US,en;q=0.9"},
        {"content-type", "application/x-www-form-urlencoded; charset=UTF-8"},
        {"sec-ch-ua", ~s("Not:A-Brand";v="99", "Google Chrome";v="145", "Chromium";v="145")},
        {"sec-ch-ua-mobile", "?0"},
        {"sec-ch-ua-platform", ~s("macOS")},
        {"sec-fetch-dest", "empty"},
        {"sec-fetch-mode", "cors"},
        {"sec-fetch-site", "same-site"},
        {"cookie", cookies}
      ],
      form: form
    )
  end

  def format_data(res) do
    case res.body do
      %{"Results" => results} when is_list(results) ->
        format_results(results)

      body when is_binary(body) ->
        Logger.error(
          "API returned non-JSON response (likely bot detection): #{String.slice(body, 0, 200)}"
        )

        []

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
