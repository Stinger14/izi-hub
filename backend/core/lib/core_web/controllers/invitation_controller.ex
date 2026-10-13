defmodule CoreWeb.InvitationController do
  @moduledoc """
  The household invitation link (`/invites/:token`). Signed-in visitors can
  accept or decline; signed-out visitors are remembered so signing in or
  creating an account brings them back here.
  """
  use CoreWeb, :controller

  alias Core.Accounts
  alias CoreWeb.UserAuth

  def show(conn, %{"token" => token}) do
    case Accounts.get_invitation_by_token(token) do
      {:ok, invitation} ->
        conn =
          if conn.assigns.current_scope,
            do: conn,
            else: UserAuth.remember_invitation(conn, token)

        render(conn, :show, invitation: invitation, token: token, problem: nil)

      {:error, reason} ->
        conn
        |> put_status(:not_found)
        |> render(:show, invitation: nil, token: token, problem: reason)
    end
  end

  def accept(conn, %{"token" => token}) do
    with %{user: user} <- conn.assigns.current_scope,
         {:ok, household} <- Accounts.accept_invitation(user, {:token, token}) do
      conn
      |> put_flash(:info, "You joined #{household.name}")
      |> redirect(to: ~p"/finance?household=#{household.id}")
    else
      nil -> sign_in_first(conn, token)
      {:error, _reason} -> invalid(conn)
    end
  end

  def decline(conn, %{"token" => token}) do
    with %{user: user} <- conn.assigns.current_scope,
         {:ok, _invitation} <- Accounts.decline_invitation(user, {:token, token}) do
      conn
      |> put_flash(:info, "Invitation declined")
      |> redirect(to: ~p"/hub")
    else
      nil -> sign_in_first(conn, token)
      {:error, _reason} -> invalid(conn)
    end
  end

  defp sign_in_first(conn, token) do
    conn
    |> UserAuth.remember_invitation(token)
    |> put_flash(:error, "Sign in to answer the invitation")
    |> redirect(to: ~p"/login")
  end

  defp invalid(conn) do
    conn
    |> put_flash(:error, "This invitation is no longer valid")
    |> redirect(to: ~p"/hub")
  end
end
