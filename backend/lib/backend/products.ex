defmodule Backend.Products do
  @moduledoc """
  Products context.

  Provides read operations over the products:
  — Listing all products
  — Fetching a set of products by ids
  — Resolving pricing and basic product attributes used in orders

  Product data is treated as reference data and is consumed by the `Orders` and `Users` contexts.
  """

  import Ecto.Query
  alias Backend.Repo
  alias Backend.Products.Product

  def list_products do
    Repo.all(Product)
  end

  def get_products_by_ids(product_ids) do
    query = from p in Product, where: p.id in ^product_ids
    Repo.all(query)
  end

  @doc """
  Get products by name (e.g., "netflix", "spotify").
  For Frontend prototype endpoint compatibility
  """
  def get_products_by_names(product_names) do
    query = from p in Product, where: p.name in ^product_names
    Repo.all(query)
  end

  @doc """
  Get a single product by its name identifier.
  For Frontend prototype endpoint compatibility
  """
  def get_product_by_name(product_name) do
    Repo.get_by(Product, name: product_name)
  end

  def create_product(attrs) do
    %Product{}
    |> Product.changeset(attrs)
    |> Repo.insert()
  end
end
