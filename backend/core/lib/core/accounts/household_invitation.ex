defmodule Core.Accounts.HouseholdInvitation do
  @moduledoc """
  An invitation to join a household, addressed to an email.

  Context: created and closed only by `Core.Accounts` (invite, accept, decline,
  revoke). Only the SHA-256 hash of the link token is stored; ids, token,
  status and expiry are set in code, never cast.

  ## Example

      HouseholdInvitation.expired?(invitation)
      #=> false
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ["pending", "accepted", "declined", "revoked"]

  schema "household_invitations" do
    field :email, :string
    field :token_hash, :string, redact: true
    field :status, :string, default: "pending"
    field :expires_at, :utc_datetime

    belongs_to :household, Core.Accounts.Household
    belongs_to :invited_by, Core.Accounts.User

    timestamps()
  end

  @doc "Valid statuses: pending, accepted, declined, revoked."
  def statuses, do: @statuses

  @doc "Validates the invited email; everything else is set by `Core.Accounts`."
  def changeset(invitation, attrs) do
    invitation
    |> cast(attrs, [:email])
    |> update_change(:email, &normalize_email/1)
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/, message: "must be a valid email")
    |> validate_length(:email, max: 160)
    |> unique_constraint([:household_id, :email],
      name: :household_invitations_pending_email_index,
      message: "already has a pending invitation"
    )
  end

  @doc "Trims and downcases an email, so invites match case-insensitively."
  def normalize_email(email) when is_binary(email),
    do: email |> String.trim() |> String.downcase()

  def normalize_email(email), do: email

  @doc "Whether the invitation's link has expired."
  def expired?(%__MODULE__{expires_at: expires_at}),
    do: DateTime.compare(expires_at, DateTime.utc_now()) != :gt
end
