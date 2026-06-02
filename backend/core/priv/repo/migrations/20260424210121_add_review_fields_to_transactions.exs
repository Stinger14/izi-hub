defmodule Core.Repo.Migrations.AddReviewFieldsToTransactions do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add :source, :string, default: "manual", null: false
      add :status, :string, default: "confirmed", null: false
      add :merchant, :string
      add :external_id, :string
      add :confidence, :float
      add :raw_description, :string
      add :review_reason, :string
    end

    create index(:transactions, [:user_id, :status])
    create index(:transactions, [:user_id, :source])

    create unique_index(:transactions, [:user_id, :external_id],
             where: "external_id IS NOT NULL",
             name: :transactions_user_id_external_id_index
           )
  end
end
