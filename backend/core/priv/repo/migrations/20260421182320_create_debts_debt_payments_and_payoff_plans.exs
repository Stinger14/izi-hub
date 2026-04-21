defmodule Core.Repo.Migrations.CreateDebtsDebtPaymentsAndPayoffPlans do
  use Ecto.Migration

  def change do
    create table(:debts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :kind, :string, null: false
      add :provider, :string
      add :principal_balance, :decimal, precision: 15, scale: 2
      add :current_balance, :decimal, precision: 15, scale: 2, null: false
      add :apr, :decimal, precision: 8, scale: 4
      add :minimum_payment, :decimal, precision: 15, scale: 2, null: false
      add :due_day, :integer
      add :opened_on, :date
      add :payoff_goal_date, :date
      add :status, :string, null: false, default: "active"
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      timestamps()
    end

    create index(:debts, [:user_id])
    create index(:debts, [:status])

    create table(:debt_payments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :amount, :decimal, precision: 15, scale: 2, null: false
      add :payment_date, :date, null: false
      add :kind, :string, null: false, default: "extra"
      add :notes, :string
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :debt_id, references(:debts, type: :binary_id, on_delete: :delete_all), null: false
      add :transaction_id, references(:transactions, type: :binary_id, on_delete: :nilify_all)
      timestamps()
    end

    create index(:debt_payments, [:user_id])
    create index(:debt_payments, [:debt_id])
    create index(:debt_payments, [:transaction_id])
    create index(:debt_payments, [:payment_date])

    create table(:debt_payoff_plans, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :strategy, :string, null: false
      add :monthly_amount, :decimal, precision: 15, scale: 2, null: false
      add :starts_on, :date, null: false
      add :target_payoff_date, :date
      add :status, :string, null: false, default: "active"
      add :snapshot, :map, null: false, default: %{}
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      timestamps()
    end

    create index(:debt_payoff_plans, [:user_id])
    create index(:debt_payoff_plans, [:status])
    create index(:debt_payoff_plans, [:strategy])
  end
end
