defmodule CoreWeb.BooksController do
  @moduledoc "Downloads a library book (PDF) at `/books/:slug` for signed-in users."

  use CoreWeb, :controller

  alias Core.Notebooks

  @doc "Sends the book file, or 404 for an unknown slug."
  def download(conn, %{"slug" => slug}) do
    case Notebooks.fetch_book(slug) do
      {:ok, path} ->
        send_download(conn, {:file, path},
          filename: Path.basename(path),
          disposition: :attachment
        )

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> text("Book not found")
    end
  end
end
