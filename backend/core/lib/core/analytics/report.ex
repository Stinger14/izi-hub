defmodule Core.Analytics.Report do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "reports" do
    field :report_type, :string
    field :title, :string
    field :description, :string
    field :file_url, :string
    field :file_type, :string
    field :status, :string, default: "pending"
    field :generated_at, :naive_datetime
    field :parameters, :map, default: %{}
    field :result_data, :map, default: %{}

    belongs_to :user, Core.Accounts.User

    timestamps()
  end

  @report_types ~w(
    expense_monthly expense_yearly income_summary
    analytics_weekly analytics_monthly portfolio_summary
    budget_analysis category_breakdown custom
  )
  @statuses ~w(pending processing completed failed)
  @file_types ~w(csv pdf json excel)

  @doc false
  def changeset(report, attrs) do
    report
    |> cast(attrs, [
      :report_type,
      :title,
      :description,
      :file_url,
      :file_type,
      :status,
      :parameters,
      :result_data,
      :generated_at,
      :user_id
    ])
    |> validate_required([:report_type, :title, :user_id])
    |> validate_length(:title, min: 1, max: 255)
    |> validate_inclusion(:report_type, @report_types)
    |> validate_inclusion(:file_type, @file_types)
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:user_id)
  end
end
