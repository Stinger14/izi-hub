defmodule Core.Accounts.UserAvatar do
  @moduledoc """
  A user's profile photo bytes, one row per user.

  Context: stored in Postgres because the deploy filesystem is ephemeral.
  Written only by `Core.Accounts.put_user_avatar/2` (which checks the image
  type) and served by `CoreWeb.AvatarController`.
  """
  use Ecto.Schema

  @primary_key {:user_id, :binary_id, autogenerate: false}

  schema "user_avatars" do
    field :content_type, :string
    field :data, :binary, redact: true
    field :byte_size, :integer

    timestamps(type: :utc_datetime)
  end
end
