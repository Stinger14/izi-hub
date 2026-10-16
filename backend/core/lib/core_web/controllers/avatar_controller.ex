defmodule CoreWeb.AvatarController do
  use CoreWeb, :controller

  alias Core.Accounts

  @doc """
  Serves a profile photo to signed-in users. URLs carry `?v=<updated at>`
  (see `CoreWeb.Layouts.avatar_path/1`), so a response can be cached forever.
  """
  def show(conn, %{"user_id" => user_id}) do
    case Accounts.get_user_avatar(user_id) do
      nil ->
        send_resp(conn, :not_found, "")

      avatar ->
        conn
        |> put_resp_content_type(avatar.content_type, nil)
        |> put_resp_header("x-content-type-options", "nosniff")
        |> put_resp_header("cache-control", "private, max-age=31536000, immutable")
        |> send_resp(:ok, avatar.data)
    end
  end
end
