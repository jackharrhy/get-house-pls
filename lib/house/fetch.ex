defmodule House.Fetch do
  def fetch_data do
    form = [
      ZoomLevel: 15,
      LatitudeMax: 47.58481,
      LongitudeMax: -52.70930,
      LatitudeMin: 47.55143,
      LongitudeMin: -52.74952,
      Sort: "6-D",
      Currency: "CAD",
      IncludeHiddenListings: false,
      RecordsPerPage: 10,
      ApplicationId: 1,
      CultureId: 1,
      CurrentPage: 1
    ]

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

      %{
        mls: result["MlsNumber"] |> String.to_integer(),
        price: property["Price"],
        address: address["AddressText"] |> String.split("|"),
        lat: address["Latitude"],
        lon: address["Latitude"],
        photos: photo |> Enum.map(& &1["HighResPath"]),
        time_on_realtor: result["TimeOnRealtor"],
        bedrooms: building["Bedrooms"],
        bathrooms: building["Bathrooms"]
      }
    end
  end

  def get_data() do
    fetch_data() |> format_data()
  end

  def test do
    get_data() |> IO.inspect()
  end
end
