defmodule Core.Repo.Migrations.CreateNotifications do
  use Ecto.Migration

  def change do
    create table(:notifications) do
      add :title, :string
      add :message, :string
      add :type, :string

      timestamps(type: :utc_datetime)
    end
  end
end
