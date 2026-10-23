defmodule Core.Repo.Migrations.CreateStudioTables do
  use Ecto.Migration

  def change do
    create table(:studio_pieces, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :title, :string, null: false
      add :kind, :string, null: false, default: "video"
      add :status, :string, null: false, default: "idea"
      add :language, :string, null: false, default: "es"
      add :notes, :text
      add :transcript, :text
      add :transcript_srt, :text
      add :published_at, :utc_datetime
      add :fb_url, :string

      timestamps(type: :utc_datetime)
    end

    create index(:studio_pieces, [:user_id, :status])

    create table(:studio_drafts, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :piece_id, references(:studio_pieces, type: :binary_id, on_delete: :delete_all),
        null: false

      add :type, :string, null: false
      add :body, :map, null: false
      add :chosen, :boolean, null: false, default: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:studio_drafts, [:piece_id, :type])
  end
end
