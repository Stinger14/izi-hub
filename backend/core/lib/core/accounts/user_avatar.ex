defmodule Core.Accounts.UserAvatar do
  @moduledoc """
  A user's profile photo, stored in Postgres (the deploy filesystem is
  ephemeral). Written only by `Core.Accounts.put_user_avatar/2`, which checks
  the bytes are a real JPEG, PNG, GIF or WebP image; nothing here is cast.
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
