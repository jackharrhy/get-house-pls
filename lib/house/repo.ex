defmodule House.Repo do
  use Ecto.Repo,
    otp_app: :house,
    adapter: Ecto.Adapters.SQLite3
end

defmodule House.Schema.House do
  use Ecto.Schema
  import Ecto.Changeset

  schema "houses" do
    field(:mls, :integer)
    field(:price, :decimal)
    field(:address, {:array, :string})
    field(:lat, :float)
    field(:lon, :float)
    field(:photos, {:array, :string})
    field(:time_on_realtor, :string)
    field(:bedrooms, :integer)
    field(:bathrooms, :float)

    timestamps()
  end

  def changeset(house, attrs) do
    house
    |> cast(attrs, [
      :mls,
      :price,
      :address,
      :lat,
      :lon,
      :photos,
      :time_on_realtor,
      :bedrooms,
      :bathrooms
    ])
    |> validate_required([:mls, :price, :address, :lat, :lon])
  end
end
