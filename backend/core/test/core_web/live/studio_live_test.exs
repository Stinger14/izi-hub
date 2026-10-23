defmodule CoreWeb.StudioLiveTest do
  use CoreWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Core.{Repo, Studio}
  alias Core.Studio.{Draft, Piece, PoloClient}

  @caption %{
    "variants" => [%{"caption" => "El mangú perfecto", "cta" => "¿Cómo lo haces tú?"}],
    "hashtags" => ["RD", "comida"]
  }

  setup %{conn: conn} do
    user = user_fixture()
    %{conn: log_in_user(conn, user), user: user}
  end

  defp piece_fixture(user) do
    {:ok, piece} =
      Studio.create_piece(user, %{"title" => "Mangú en 60 segundos", "notes" => "Tres golpes"})

    piece
  end

  defp open_piece(conn, piece) do
    {:ok, view, _html} = live(conn, ~p"/studio")
    view |> element("#piece-#{piece.id}") |> render_click()
    view
  end

  test "signed-out visitors are sent to sign in", %{conn: _conn} do
    assert {:error, {:redirect, %{to: "/login" <> _}}} = live(build_conn(), ~p"/studio")
  end

  test "shows an empty state, then adds and selects a piece", %{conn: conn, user: user} do
    {:ok, view, html} = live(conn, ~p"/studio")
    assert html =~ "Add an idea above"

    html = view |> form("#new-piece-form", piece: %{title: "Receta de mangú"}) |> render_submit()

    assert [%Piece{title: "Receta de mangú"} = piece] = Studio.list_pieces(user)
    assert html =~ "Receta de mangú"
    assert has_element?(view, "#piece-#{piece.id}[aria-current]")
    assert has_element?(view, "#piece-form")
  end

  test "saves the piece form", %{conn: conn, user: user} do
    piece = piece_fixture(user)
    view = open_piece(conn, piece)

    view
    |> form("#piece-form", piece: %{title: "Mangú en 30", kind: "reel", status: "scripting"})
    |> render_submit()

    assert %Piece{title: "Mangú en 30", kind: "reel", status: "scripting"} =
             Repo.get!(Piece, piece.id)
  end

  test "generating a caption saves and shows the draft", %{conn: conn, user: user} do
    piece = piece_fixture(user)
    Req.Test.stub(PoloClient, &Req.Test.json(&1, @caption))
    view = open_piece(conn, piece)

    assert view |> element("#generate-caption") |> render_click() =~ "Writing…"
    html = render_async(view)

    assert html =~ "El mangú perfecto"
    assert html =~ "#RD #comida"
    assert [%Draft{type: "caption", body: @caption}] = Studio.list_drafts(piece)
    refute has_element?(view, "#generate-caption[disabled]")
  end

  test "a service error shows a flash and frees the buttons", %{conn: conn, user: user} do
    piece = piece_fixture(user)

    Req.Test.stub(PoloClient, fn conn ->
      conn
      |> Plug.Conn.put_status(422)
      |> Req.Test.json(%{"detail" => "The AI declined to write this."})
    end)

    view = open_piece(conn, piece)
    view |> element("#generate-hooks") |> render_click()

    assert render_async(view) =~ "The AI declined to write this."
    assert Studio.list_drafts(piece) == []
    refute has_element?(view, "#generate-hooks[disabled]")
  end

  test "ignores unknown generate types", %{conn: conn, user: user} do
    piece = piece_fixture(user)
    view = open_piece(conn, piece)

    render_click(view, "generate", %{"type" => "poem"})

    refute has_element?(view, "#generate-caption[disabled]")
  end

  test "'Use this draft' marks the draft as in use", %{conn: conn, user: user} do
    piece = piece_fixture(user)
    {:ok, draft} = Studio.save_draft(user, piece, "caption", @caption)
    view = open_piece(conn, piece)

    view |> element(~s(#draft-#{draft.id} button[aria-label="Use this draft"])) |> render_click()

    assert Repo.get!(Draft, draft.id).chosen
    assert has_element?(view, "#draft-#{draft.id}", "In use")
  end

  test "deletes a piece only after confirming", %{conn: conn, user: user} do
    piece = piece_fixture(user)
    view = open_piece(conn, piece)

    view |> element(~s(button[aria-label="Delete piece"])) |> render_click()
    assert Repo.get(Piece, piece.id)

    view |> element("button", "Delete") |> render_click()

    assert Repo.get(Piece, piece.id) == nil
    refute has_element?(view, "#piece-#{piece.id}")
  end

  test "another user's piece can't be opened", %{conn: conn} do
    theirs = piece_fixture(user_fixture())
    {:ok, view, _html} = live(conn, ~p"/studio")

    render_click(view, "select_piece", %{"id" => theirs.id})

    refute has_element?(view, "#piece-form")
  end

  test "reloads when another tab changes a piece", %{conn: conn, user: user} do
    {:ok, view, _html} = live(conn, ~p"/studio")

    Task.async(fn -> Studio.create_piece(user, %{"title" => "From another tab"}) end)
    |> Task.await()

    assert render(view) =~ "From another tab"
  end
end
