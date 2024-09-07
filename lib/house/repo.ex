defmodule House.Repo do
  use Ecto.Repo,
    otp_app: :house,
    adapter: Ecto.Adapters.SQLite3
end

defmodule House.Schema.House do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias House.Repo

  @primary_key {:mls, :integer, autogenerate: false}
  schema "houses" do
    field(:price, :decimal)
    field(:address, {:array, :string})
    field(:lat, :float)
    field(:lon, :float)
    field(:photos, {:array, :string})
    field(:time_on_realtor, :string)
    field(:bedrooms, :integer)
    field(:bathrooms, :integer)

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
    |> validate_required([:mls, :address, :lat, :lon])
  end

  def exists?(mls) do
    query = from(h in House.Schema.House, where: h.mls == ^mls)
    Repo.exists?(query)
  end

  def insert_house(attrs) do
    IO.inspect(attrs)

    %House.Schema.House{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  def update_house(attrs) do
    house = Repo.get!(House.Schema.House, attrs.mls)

    house
    |> changeset(attrs)
    |> Repo.update()
  end
end
