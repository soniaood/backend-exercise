alias Backend.Repo
alias Backend.Products.Product
alias Backend.Orders.{Order, OrderItem}
alias Backend.Users.{User, UserProduct}

# Clear existing data in proper order (respecting foreign keys)
Repo.delete_all(OrderItem)
Repo.delete_all(UserProduct)
Repo.delete_all(Order)
Repo.delete_all(User)
Repo.delete_all(Product)

# Seed products
products = [
  %{id: "netflix", name: "Netflix Subscription", price: Decimal.new("75.99")},
  %{id: "spotify", name: "Spotify Premium", price: Decimal.new("45.99")},
  %{id: "gym", name: "Gym Membership", price: Decimal.new("120.00")},
  %{id: "transport", name: "Transport Card", price: Decimal.new("89.90")},
  %{id: "lunch", name: "Lunch Vouchers", price: Decimal.new("200.00")}
]

Enum.each(products, fn product_attrs ->
  %Product{}
  |> Product.changeset(product_attrs)
  |> Repo.insert!()
end)

IO.puts("Seeded #{length(products)} products")
