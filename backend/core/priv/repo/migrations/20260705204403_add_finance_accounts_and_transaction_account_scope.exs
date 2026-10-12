defmodule Core.Repo.Migrations.AddFinanceAccountsAndTransactionAccountScope do
  use Ecto.Migration

  def change do
    create table(:finance_accounts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :institution, :string
      add :kind, :string, null: false
      add :currency, :string, null: false, default: "USD"
      add :current_balance, :decimal, null: false, default: 0
      add :available_balance, :decimal
      add :status, :string, null: false, default: "active"
      add :last_synced_at, :utc_datetime_usec
      add :notes, :string
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all)

      timestamps()
    end

    alter table(:transactions) do
      add :account_id, references(:finance_accounts, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:finance_accounts, [:user_id])
    create index(:finance_accounts, [:household_id])
    create index(:finance_accounts, [:status])

    create unique_index(:finance_accounts, [:user_id, :name],
             where: "user_id IS NOT NULL",
             name: :finance_accounts_user_id_name_index
           )

    create unique_index(:finance_accounts, [:household_id, :name],
             where: "household_id IS NOT NULL",
             name: :finance_accounts_household_id_name_index
           )

    create constraint(:finance_accounts, :finance_accounts_exactly_one_owner_scope,
             check: "(user_id IS NOT NULL) <> (household_id IS NOT NULL)"
           )

    create index(:transactions, [:account_id])
  end
end
