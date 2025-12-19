defmodule Core.Repo.Migrations.CreateComments do
  use Ecto.Migration

  def change do
    create table(:comments) do
      add :content, :string
      add :author_name, :string
      add :author_email, :string

      timestamps(type: :utc_datetime)
    end
  end
end
