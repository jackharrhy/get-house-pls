defmodule House.RepoTest do
  use ExUnit.Case
  alias House.Repo
  alias House.Schema.House

  test "CRUD operations on House" do
    test_house = %House{
      mls: 12345,
      price: Decimal.new("500000.00"),
      address: ["123 Main St", "Anytown", "ST", "12345"],
      lat: 40.7128,
      lon: -74.0060,
      photos: ["https://example.com/photo1.jpg", "https://example.com/photo2.jpg"],
      time_on_realtor: "30 days",
      bedrooms: 3,
      bathrooms: 2.5
    }

    # Create
    {:ok, inserted_house} = Repo.insert(test_house)
    assert inserted_house.id != nil

    # Read
    fetched_house = Repo.get(House, inserted_house.id)
    assert fetched_house.mls == test_house.mls

    # Update
    {:ok, updated_house} =
      Repo.update(House.changeset(fetched_house, %{price: Decimal.new("525000.00")}))

    assert Decimal.eq?(updated_house.price, Decimal.new("525000.00"))

    # Delete
    {:ok, deleted_house} = Repo.delete(updated_house)
    assert deleted_house.id == updated_house.id

    # Verify deletion
    nil_result = Repo.get(House, deleted_house.id)
    assert nil_result == nil
  end
end
