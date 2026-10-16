defmodule CoreWeb.RegistrationController do
  @moduledoc """
  `/signup`: creates an account from an email (prefilled with `?email=`); the
  user then picks a password at `/set-password`.
  """

  use CoreWeb, :controller

  alias Core.Accounts

  @doc "Shows the sign-up form."
  def new(conn, params) do
    form_data =
      case params do
        %{"email" => email} when is_binary(email) -> %{"email" => String.trim(email)}
        _ -> %{}
      end

    render(conn, :new, errors: [], form_data: form_data)
  end

  @doc """
  Creates the account from the email and sends the user to `/set-password`, or
  re-renders with errors.
  """
  def create(conn, %{"user" => user_params}) do
    case Accounts.register_email_only_user(extract_email(user_params)) do
      {:ok, _user, setup_token} ->
        conn
        |> put_flash(:info, "Account created. Set your password to continue.")
        |> redirect(to: ~p"/set-password?token=#{setup_token}")

      {:error, :username_generation_failed} ->
        render_registration_error(conn, user_params, [
          "Unable to generate a unique username. Please try again."
        ])

      {:error, %Ecto.Changeset{} = changeset} ->
        render_registration_error(conn, user_params, registration_errors(changeset))
    end
  end

  def create(conn, _params) do
    render_registration_error(conn, %{}, ["Invalid signup payload"])
  end

  defp render_registration_error(conn, form_data, errors) do
    conn
    |> put_status(:unprocessable_entity)
    |> render(:new, errors: errors, form_data: form_data)
  end

  defp registration_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _match, key ->
        opts
        |> Enum.find_value(key, fn {opt_key, value} ->
          if Atom.to_string(opt_key) == key, do: value
        end)
        |> to_string()
      end)
    end)
    |> Enum.flat_map(fn {field, errors} ->
      Enum.map(errors, fn error -> "#{format_field(field)} #{error}" end)
    end)
  end

  defp format_field(field) do
    field
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp extract_email(%{"email" => email}) when is_binary(email), do: String.trim(email)
  defp extract_email(%{email: email}) when is_binary(email), do: String.trim(email)
  defp extract_email(_), do: ""
end
