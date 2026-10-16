defmodule CoreWeb.AvatarController do
  @moduledoc """
  Serves profile photos at `/avatars/:user_id` to signed-in users.

  Context: bytes come from `Core.Accounts.get_user_avatar/1`; responses are
  `nosniff` and cached for a year, since URLs carry a `?v=` version.
  """

  use CoreWeb, :controller

  alias Core.Accounts

  @doc "Sends the photo with its stored type, or 404."
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
