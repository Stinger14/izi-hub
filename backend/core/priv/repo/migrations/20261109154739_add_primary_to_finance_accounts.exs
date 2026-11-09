defmodule Core.Repo.Migrations.AddPrimaryToFinanceAccounts do
  use Ecto.Migration

  def up do
    alter table(:finance_accounts) do
      # The scope's default account (dashboard, transfer "From", new
      # transactions). At most one per personal scope or household.
      add :is_primary, :boolean, null: false, default: false
    end

    create unique_index(:finance_accounts, [:user_id],
             where: "is_primary AND household_id IS NULL",
             name: :finance_accounts_one_primary_per_user
           )

    create unique_index(:finance_accounts, [:household_id],
             where: "is_primary AND household_id IS NOT NULL",
             name: :finance_accounts_one_primary_per_household
           )

    # Existing scopes: star the account the dashboard already led with
    # (first active one by kind, then name).
    execute("""
    UPDATE finance_accounts SET is_primary = true
    WHERE id IN (
      SELECT DISTINCT ON (COALESCE(household_id, user_id)) id
      FROM finance_accounts
      WHERE status = 'active'
      ORDER BY COALESCE(household_id, user_id), kind, name
    )
    """)
  end

  def down do
    drop index(:finance_accounts, [:household_id],
           name: :finance_accounts_one_primary_per_household
         )

    drop index(:finance_accounts, [:user_id], name: :finance_accounts_one_primary_per_user)

    alter table(:finance_accounts) do
      remove :is_primary
    end
  end
end
