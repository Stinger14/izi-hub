defmodule Core.Repo.Migrations.AddCounterpartToTransactions do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add :counterpart_transaction_id,
          references(:transactions, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:transactions, [:counterpart_transaction_id])
  end
end
