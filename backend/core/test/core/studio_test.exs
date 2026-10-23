defmodule Core.StudioTest do
  use Core.DataCase, async: true

  alias Core.Repo
  alias Core.Studio
  alias Core.Studio.{Draft, Piece}

  @caption %{"variants" => [%{"caption" => "Hola", "cta" => "Comenta"}], "hashtags" => ["RD"]}

  setup do
    %{user: user_fixture(), other: user_fixture()}
  end

  defp piece_fixture(user, attrs \\ %{}) do
    {:ok, piece} =
      Studio.create_piece(user, Enum.into(attrs, %{"title" => "Mangú en 60 segundos"}))

    piece
  end

  describe "pieces" do
    test "create and list are scoped to the user", %{user: user, other: other} do
      piece = piece_fixture(user)
      _theirs = piece_fixture(other, %{"title" => "Theirs"})

      assert [%Piece{id: id, status: "idea", language: "es"}] = Studio.list_pieces(user)
      assert id == piece.id
      assert piece.user_id == user.id
    end

    test "create validates the title and the choice fields", %{user: user} do
      assert {:error, changeset} = Studio.create_piece(user, %{"title" => "", "kind" => "tiktok"})
      assert %{title: [_], kind: [_]} = errors_on(changeset)
    end

    test "get_piece returns nil for another user's piece or a malformed id", %{
      user: user,
      other: other
    } do
      piece = piece_fixture(user)

      assert Studio.get_piece(user, piece.id).id == piece.id
      assert Studio.get_piece(other, piece.id) == nil
      assert Studio.get_piece(user, "not-a-uuid") == nil
    end

    test "update changes editable fields only", %{user: user} do
      piece = piece_fixture(user)

      assert {:ok, updated} =
               Studio.update_piece(user, piece, %{
                 "notes" => "Tres golpes",
                 "kind" => "reel",
                 "transcript" => "sneaky",
                 "user_id" => Ecto.UUID.generate()
               })

      assert updated.notes == "Tres golpes"
      assert updated.kind == "reel"
      assert updated.transcript == nil
      assert updated.user_id == user.id
    end

    test "update and delete refuse another user's piece", %{user: user, other: other} do
      piece = piece_fixture(user)

      assert {:error, :forbidden} = Studio.update_piece(other, piece, %{"title" => "Mine now"})
      assert {:error, :forbidden} = Studio.delete_piece(other, piece)
      assert Repo.get!(Piece, piece.id).title == piece.title
    end

    test "delete removes the piece and its drafts", %{user: user} do
      piece = piece_fixture(user)
      {:ok, draft} = Studio.save_draft(user, piece, "caption", @caption)

      assert {:ok, _} = Studio.delete_piece(user, piece)
      assert Repo.get(Piece, piece.id) == nil
      assert Repo.get(Draft, draft.id) == nil
    end
  end

  describe "drafts" do
    test "save_draft stores the AI body for the owner only", %{user: user, other: other} do
      piece = piece_fixture(user)

      assert {:ok, %Draft{type: "caption", body: @caption, chosen: false}} =
               Studio.save_draft(user, piece, "caption", @caption)

      assert {:error, :forbidden} = Studio.save_draft(other, piece, "caption", @caption)
      assert {:error, changeset} = Studio.save_draft(user, piece, "poem", @caption)
      assert %{type: [_]} = errors_on(changeset)
      assert [%Draft{}] = Studio.list_drafts(piece)
    end

    test "save_draft returns an error when the piece was deleted meanwhile", %{user: user} do
      piece = piece_fixture(user)
      {:ok, _} = Studio.delete_piece(user, piece)

      assert {:error, %Ecto.Changeset{}} = Studio.save_draft(user, piece, "caption", @caption)
    end

    test "choose_draft keeps one chosen draft per type", %{user: user} do
      piece = piece_fixture(user)
      {:ok, first} = Studio.save_draft(user, piece, "caption", @caption)
      {:ok, second} = Studio.save_draft(user, piece, "caption", @caption)
      {:ok, hooks} = Studio.save_draft(user, piece, "hooks", %{"hooks" => []})
      {:ok, _} = Studio.choose_draft(user, hooks)

      {:ok, _} = Studio.choose_draft(user, first)
      {:ok, _} = Studio.choose_draft(user, second)

      chosen = piece |> Studio.list_drafts() |> Enum.filter(& &1.chosen) |> Enum.map(& &1.id)
      assert Enum.sort(chosen) == Enum.sort([second.id, hooks.id])
    end

    test "drafts are only reachable through their piece's owner", %{user: user, other: other} do
      piece = piece_fixture(user)
      {:ok, draft} = Studio.save_draft(user, piece, "caption", @caption)

      assert Studio.get_draft(user, draft.id).id == draft.id
      assert Studio.get_draft(other, draft.id) == nil
      assert Studio.get_draft(user, "nope") == nil
      assert {:error, :forbidden} = Studio.choose_draft(other, draft)
    end
  end

  describe "live updates" do
    test "successful writes broadcast on the user's topic", %{user: user} do
      :ok = Studio.subscribe(user)
      user_id = user.id

      {:ok, piece} = elsewhere(fn -> Studio.create_piece(user, %{"title" => "Broadcast me"}) end)
      assert_receive {:studio_changed, ^user_id}

      {:ok, _} = elsewhere(fn -> Studio.save_draft(user, piece, "caption", @caption) end)
      assert_receive {:studio_changed, ^user_id}
    end

    test "failed writes and the writer's own process don't get a broadcast", %{user: user} do
      :ok = Studio.subscribe(user)

      assert {:error, _} = elsewhere(fn -> Studio.create_piece(user, %{"title" => ""}) end)
      {:ok, _} = Studio.create_piece(user, %{"title" => "My own write"})

      refute_receive {:studio_changed, _}
    end
  end

  # Run a write in another process, like a different LiveView would.
  defp elsewhere(fun), do: fun |> Task.async() |> Task.await()
end
