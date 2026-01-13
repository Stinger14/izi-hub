defmodule Core.Repo.Migrations.CreateReports do
  use Ecto.Migration

  def change do
    create table(:reports, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :report_type, :string
      add :title, :string
      add :description, :string
      add :file_url, :string
      add :file_type, :string
      add :status, :string, default: "pending"
      add :generated_at, :naive_datetime
      add :parameters, :map, default: %{}
      add :result_data, :map, default: %{}
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      timestamps()
    end

    create index(:reports, [:user_id])
  end
end
