defmodule House.Repo.Migrations.AddHouseTable do
  use Ecto.Migration

  def change do
    create table(:houses, primary_key: false) do
      add :mls, :integer, primary_key: true
      add :price, :decimal, null: true
      add :address, {:array, :string}, null: false
      add :lat, :float, null: false
      add :lon, :float, null: false
      add :photos, {:array, :string}
      add :time_on_realtor, :string
      add :bedrooms, :integer
      add :bathrooms, :integer

      timestamps()
    end

    create unique_index(:houses, [:mls])
  end
end
