defmodule CoreWeb.PasswordSetupController do
  use CoreWeb, :controller

  alias Core.Accounts

  def new(conn, %{"token" => token}) do
    with {:ok, user} <- Accounts.get_user_by_token(token, "setup_password") do
      render(conn, :new, token: token, username: user.username, errors: [])
    else
      _ ->
        conn
        |> put_flash(:error, "Password setup link is invalid or expired")
        |> redirect(to: ~p"/hub?auth=signup")
    end
  end

  def new(conn, _params) do
    conn
    |> put_flash(:error, "Missing password setup token")
    |> redirect(to: ~p"/hub?auth=signup")
  end

  def create(conn, %{"user" => %{"token" => token, "password" => password}}) do
    case Accounts.set_password_from_setup_token(token, password) do
      {:ok, user} ->
        _ = Accounts.update_last_login(user)

        conn
        |> configure_session(renew: true)
        |> put_session(:user_id, user.id)
        |> put_flash(:info, "Password set successfully. Welcome.")
        |> redirect(to: after_setup_path(user))

      {:error, :invalid_or_expired_token} ->
        conn
        |> put_flash(:error, "Password setup link is invalid or expired")
        |> redirect(to: ~p"/hub?auth=signup")

      {:error, %Ecto.Changeset{} = changeset} ->
        render_with_changeset_errors(conn, token, changeset)
    end
  end

  def create(conn, %{"user" => %{"token" => token}}) do
    render_with_errors(conn, token, ["Password can't be blank"])
  end

  def create(conn, _params) do
    conn
    |> put_flash(:error, "Invalid password setup payload")
    |> redirect(to: ~p"/hub?auth=signup")
  end

  defp render_with_changeset_errors(conn, token, changeset) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
        Regex.replace(~r"%{(\w+)}", msg, fn _match, key ->
          opts
          |> Enum.find_value(key, fn {opt_key, value} ->
            if Atom.to_string(opt_key) == key, do: value
          end)
          |> to_string()
        end)
      end)
      |> Enum.flat_map(fn {field, field_errors} ->
        Enum.map(field_errors, fn error -> "#{format_field(field)} #{error}" end)
      end)

    render_with_errors(conn, token, errors)
  end

  defp render_with_errors(conn, token, errors) do
    with {:ok, user} <- Accounts.get_user_by_token(token, "setup_password") do
      render(conn, :new, token: token, username: user.username, errors: errors)
    else
      _ ->
        conn
        |> put_flash(:error, "Password setup link is invalid or expired")
        |> redirect(to: ~p"/hub?auth=signup")
    end
  end

  defp format_field(field) do
    field
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp after_setup_path(%{role: "admin"}), do: ~p"/admin"
  defp after_setup_path(_user), do: ~p"/hub"
end
