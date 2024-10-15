defmodule House.Fetch do
  def fetch_data do
    form =
      [
        Sort: "6-D",
        Currency: "CAD",
        IncludeHiddenListings: false,
        RecordsPerPage: 10,
        ApplicationId: 1,
        CultureId: 1,
        CurrentPage: 1
      ] ++ Application.fetch_env!(:house, :realtor_post_config)

    Req.post!(
      "https://api2.realtor.ca/Listing.svc/PropertySearch_Post",
      headers: [
        "User-Agent":
          "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:129.0) Gecko/20100101 Firefox/129.0",
        Referer: "https://www.realtor.ca/",
        Origin: "https://www.realtor.ca/",
        Host: "api2.realtor.ca",
        Cookie: "reese84=not-a-user-lol"
      ],
      form: form
    )
  end

  def format_data(res) do
    for result <- res.body["Results"] do
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
