defmodule Core.Repo.Migrations.RenameBudgetAlertThreshold do
  use Ecto.Migration

  def change do
    rename table(:budgets), :alert_thershold, to: :alert_threshold
  end
end
