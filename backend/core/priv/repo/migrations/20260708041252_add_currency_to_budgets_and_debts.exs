defmodule Core.Repo.Migrations.AddCurrencyToBudgetsAndDebts do
  use Ecto.Migration

  def change do
    alter table(:budgets) do
      add :currency, :string, null: false, default: "DOP"
    end

    alter table(:debts) do
      add :currency, :string, null: false, default: "DOP"
    end
  end
end
