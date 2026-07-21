defmodule Core.Repo.Migrations.AddHouseholdScopeToFinanceRecords do
  use Ecto.Migration

  def change do
    alter table(:categories) do
      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all)
    end

    alter table(:transactions) do
      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all)
    end

    alter table(:budgets) do
      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all)
    end

    alter table(:debts) do
      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all)
    end

    alter table(:debt_payments) do
      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all)
    end

    alter table(:debt_payoff_plans) do
      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all)
    end

    execute "ALTER TABLE budgets ALTER COLUMN user_id DROP NOT NULL",
            "ALTER TABLE budgets ALTER COLUMN user_id SET NOT NULL"

    execute "ALTER TABLE debts ALTER COLUMN user_id DROP NOT NULL",
            "ALTER TABLE debts ALTER COLUMN user_id SET NOT NULL"

    execute "ALTER TABLE debt_payments ALTER COLUMN user_id DROP NOT NULL",
            "ALTER TABLE debt_payments ALTER COLUMN user_id SET NOT NULL"

    execute "ALTER TABLE debt_payoff_plans ALTER COLUMN user_id DROP NOT NULL",
            "ALTER TABLE debt_payoff_plans ALTER COLUMN user_id SET NOT NULL"

    create index(:categories, [:household_id])

    create unique_index(:categories, [:household_id, :name, :type],
             where: "household_id IS NOT NULL",
             name: :categories_household_id_name_type_index
           )

    create index(:transactions, [:household_id])
    create index(:transactions, [:household_id, :status])
    create index(:transactions, [:household_id, :source])

    create unique_index(:transactions, [:household_id, :external_id],
             where: "household_id IS NOT NULL AND external_id IS NOT NULL",
             name: :transactions_household_id_external_id_index
           )

    create index(:budgets, [:household_id])
    create index(:debts, [:household_id])
    create index(:debt_payments, [:household_id])
    create index(:debt_payoff_plans, [:household_id])

    create constraint(:categories, :categories_exactly_one_owner_scope,
             check: "(user_id IS NOT NULL) <> (household_id IS NOT NULL)"
           )

    create constraint(:transactions, :transactions_exactly_one_owner_scope,
             check: "(user_id IS NOT NULL) <> (household_id IS NOT NULL)"
           )

    create constraint(:budgets, :budgets_exactly_one_owner_scope,
             check: "(user_id IS NOT NULL) <> (household_id IS NOT NULL)"
           )

    create constraint(:debts, :debts_exactly_one_owner_scope,
             check: "(user_id IS NOT NULL) <> (household_id IS NOT NULL)"
           )

    create constraint(:debt_payments, :debt_payments_exactly_one_owner_scope,
             check: "(user_id IS NOT NULL) <> (household_id IS NOT NULL)"
           )

    create constraint(:debt_payoff_plans, :debt_payoff_plans_exactly_one_owner_scope,
             check: "(user_id IS NOT NULL) <> (household_id IS NOT NULL)"
           )
  end
end
