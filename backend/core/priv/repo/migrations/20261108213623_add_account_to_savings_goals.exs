defmodule Core.Repo.Migrations.AddAccountToSavingsGoals do
  use Ecto.Migration

  def change do
    alter table(:savings_goals) do
      # Optional account the goal's money lives in; contributions from another
      # account become transfers into it.
      add :account_id, references(:finance_accounts, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:savings_goals, [:account_id])
  end
end
