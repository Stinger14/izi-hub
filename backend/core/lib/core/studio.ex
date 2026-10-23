defmodule Core.Studio do
  @moduledoc """
  Polo Studio: a creator's content pieces and the AI drafts saved against them.

  Context: the AI work happens in the `polo_studio` service (called through
  `Core.Studio.PoloClient`); this context is the system of record. Writes take
  the acting user first, check ownership (`{:error, :forbidden}` otherwise) and
  broadcast `{:studio_changed, user_id}` on `"studio:user:<id>"` via
  `broadcast_from(self(), …)`, so other tabs reload and the writer skips its echo.
  """
  import Ecto.Query

  alias Core.Accounts.User
  alias Core.Repo
  alias Core.Studio.{Draft, Piece}

  @pubsub Core.PubSub

  @doc "Subscribes the caller to the user's Studio changes."
  def subscribe(%User{id: id}), do: Phoenix.PubSub.subscribe(@pubsub, topic(id))

  defp topic(user_id), do: "studio:user:#{user_id}"

  defp broadcast_change({:ok, _} = result, user_id) do
    Phoenix.PubSub.broadcast_from(@pubsub, self(), topic(user_id), {:studio_changed, user_id})
    result
  end

  defp broadcast_change(result, _user_id), do: result

  @doc "The user's pieces, most recently changed first."
  def list_pieces(%User{id: user_id}) do
    Piece
    |> where(user_id: ^user_id)
    |> order_by(desc: :updated_at, desc: :inserted_at)
    |> Repo.all()
  end

  @doc """
  The user's piece with this id, or `nil` (also for another user's piece or an
  id that isn't a UUID, since ids arrive from the browser).
  """
  def get_piece(%User{id: user_id}, id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} -> Repo.get_by(Piece, id: uuid, user_id: user_id)
      :error -> nil
    end
  end

  @doc "Creates a piece owned by the user."
  def create_piece(%User{} = user, attrs) do
    %Piece{user_id: user.id}
    |> Piece.changeset(attrs)
    |> Repo.insert()
    |> broadcast_change(user.id)
  end

  @doc "Updates a piece's editable fields (owner only)."
  def update_piece(%User{} = user, %Piece{} = piece, attrs) do
    with :ok <- ensure_owner(user, piece) do
      piece
      |> Piece.changeset(attrs)
      |> Repo.update()
      |> broadcast_change(user.id)
    end
  end

  @doc "Deletes a piece and, by cascade, its drafts (owner only)."
  def delete_piece(%User{} = user, %Piece{} = piece) do
    with :ok <- ensure_owner(user, piece) do
      piece
      # another tab may have deleted it already; that's still a success
      |> Repo.delete(allow_stale: true)
      |> broadcast_change(user.id)
    end
  end

  @doc """
  A piece's drafts, newest first. Takes the piece rather than the user: a
  `%Piece{}` only comes from the user-scoped `list_pieces/1` or `get_piece/2`.
  """
  def list_drafts(%Piece{id: piece_id}) do
    Draft
    |> where(piece_id: ^piece_id)
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  @doc """
  Saves an AI result as a draft of the piece (owner only). `type` and `body`
  come from code (the helper used and its response), not from a form.
  """
  def save_draft(%User{} = user, %Piece{} = piece, type, body) do
    with :ok <- ensure_owner(user, piece) do
      %Draft{piece_id: piece.id}
      |> Draft.changeset(%{type: type, body: body})
      |> Repo.insert()
      |> broadcast_change(user.id)
    end
  end

  @doc """
  Marks the draft as the one to use and unmarks the piece's other drafts of the
  same type. Ownership lives on the piece, so it's loaded through `get_piece/2`.
  """
  def choose_draft(%User{} = user, %Draft{} = draft) do
    case get_piece(user, draft.piece_id) do
      nil ->
        {:error, :forbidden}

      %Piece{} ->
        # update_all rather than a changeset: the struct may be stale (say,
        # chosen: true in memory but reset since), and a changeset would then
        # see "no change" and skip the write
        Repo.transaction(fn ->
          siblings = where(Draft, [d], d.piece_id == ^draft.piece_id and d.type == ^draft.type)
          Repo.update_all(siblings, set: [chosen: false])
          Repo.update_all(where(Draft, id: ^draft.id), set: [chosen: true])
          %{draft | chosen: true}
        end)
        |> broadcast_change(user.id)
    end
  end

  @doc "The draft with this id if it belongs to one of the user's pieces, or `nil`."
  def get_draft(%User{id: user_id}, id) do
    with {:ok, uuid} <- Ecto.UUID.cast(id) do
      Draft
      |> join(:inner, [d], p in Piece, on: p.id == d.piece_id)
      |> where([d, p], d.id == ^uuid and p.user_id == ^user_id)
      |> Repo.one()
    else
      :error -> nil
    end
  end

  defp ensure_owner(%User{id: id}, %{user_id: id}), do: :ok
  defp ensure_owner(_user, _record), do: {:error, :forbidden}
end
