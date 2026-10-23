defmodule Core.Repo.Migrations.CreateUserAvatars do
  use Ecto.Migration

  def change do
    # The image lives in its own table so loading a user (every request) never
    # pulls the bytes; users.avatar_updated_at is enough to build its URL.
    create table(:user_avatars, primary_key: false) do
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all),
        primary_key: true

      add :content_type, :string, null: false
      add :data, :binary, null: false
      add :byte_size, :integer, null: false

      timestamps(type: :utc_datetime)
    end

    alter table(:users) do
      add :avatar_updated_at, :utc_datetime
    end
  end
end
