defmodule Core.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string
      add :hashed_password, :string
      add :username, :string
      add :full_name, :string
      add :avatar_url, :string
      add :role, :string, default: "user"
      add :is_active, :boolean, default: false
      add :email_verified, :boolean, default: false
      add :email_verified_at, :naive_datetime
      add :last_login_at, :naive_datetime
      timestamps()
    end

    create unique_index(:users, [:email])
    create unique_index(:users, [:username])
  end
end
