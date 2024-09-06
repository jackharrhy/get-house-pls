defmodule House.Repo.Migrations.AddHouseTable do
  use Ecto.Migration

  def change do
    create table(:houses) do
      add :mls, :integer, null: false
      add :price, :decimal, null: false
      add :address, {:array, :string}, null: false
      add :lat, :float, null: false
      add :lon, :float, null: false
      add :photos, {:array, :string}
      add :time_on_realtor, :string
      add :bedrooms, :integer
      add :bathrooms, :float

      timestamps()
    end

    create unique_index(:houses, [:mls])
  end
end
