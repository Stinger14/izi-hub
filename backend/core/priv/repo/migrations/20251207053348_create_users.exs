defmodule Core.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :string
      add :hashed_password, :string
      add :password, :string
      add :username, :string
      add :avatar_url, :string

      timestamps(type: :utc_datetime)
    end
  end
end
