defmodule Core.Repo.Migrations.CreateReports do
  use Ecto.Migration

  def change do
    create table(:reports) do
      add :report_type, :string
      add :title, :string
      add :description, :string
      add :file_url, :string
      add :file_type, :string
      add :status, :string
      add :generated_at, :naive_datetime

      timestamps()
    end
  end
end
