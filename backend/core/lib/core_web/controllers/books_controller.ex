defmodule CoreWeb.BooksController do
  use CoreWeb, :controller

  alias Core.Notebooks

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
