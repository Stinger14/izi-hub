defmodule Core.Repo.Migrations.AddBalanceAdjustmentToTransactions do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      # A balance correction ("Adjust balance"): it moves the account balance
      # but never counts as income or spending.
      add :balance_adjustment, :boolean, null: false, default: false
    end
  end
end
