defmodule Core.Analytics.PageView do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "page_views" do
    field :page_path, :string
    field :referrer, :string
    field :user_agent, :string
    field :country, :string
    field :city, :string
    field :device_type, :string
    field :browser, :string
    field :os, :string
    field :session_id, :string
    field :duration_seconds, :integer

    belongs_to :user, Core.Accounts.User

    timestamps(updated_at: false)
  end

  @device_types ~w(desktop mobile tablet bot unknown)a

  @doc false
  def changeset(page_view, attrs) do
    page_view
    |> cast(attrs, [
      :page_path,
      :referrer,
      :user_agent,
      :country,
      :city,
      :device_type,
      :browser,
      :os,
      :session_id,
      :duration_seconds,
      :user_id
    ])
    |> validate_required([:page_path])
    |> validate_length(:page_path, max: 500)
    |> validate_inclusion(:device_type, @device_types)
    |> foreign_key_constraint(:user_id)
  end
end
