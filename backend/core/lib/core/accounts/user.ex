defmodule Core.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :hashed_password, :string
    field :password, :string
    field :username, :string
    field :avatar_url, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :hashed_password, :password, :username, :avatar_url])
    |> validate_required([:email, :hashed_password, :password, :username, :avatar_url])
  end
end
