defmodule Core.Repo.Migrations.CreateHouseholdInvitations do
  use Ecto.Migration

  def change do
    create table(:household_invitations, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all),
        null: false

      add :invited_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :email, :string, null: false
      add :token_hash, :string, null: false
      add :status, :string, null: false, default: "pending"
      add :expires_at, :utc_datetime, null: false

      timestamps()
    end

    create unique_index(:household_invitations, [:token_hash])
    create index(:household_invitations, [:email, :status])

    # One open invitation per household and email; re-inviting refreshes it.
    create unique_index(:household_invitations, [:household_id, :email],
             where: "status = 'pending'",
             name: :household_invitations_pending_email_index
           )
  end
end
