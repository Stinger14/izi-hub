defmodule CoreWeb.RegistrationController do
  use CoreWeb, :controller

  alias Core.Accounts

  def new(conn, _params) do
    redirect(conn, to: ~p"/hub?auth=signup")
  end

  def create(conn, %{"user" => user_params}) do
    case Accounts.register_email_only_user(extract_email(user_params)) do
      {:ok, _user, setup_token} ->
        conn
        |> put_flash(:info, "Account created. Set your password to continue.")
        |> redirect(to: ~p"/set-password?token=#{setup_token}")

      {:error, :username_generation_failed} ->
        conn
        |> put_flash(:error, "Unable to generate a unique username. Please try again.")
        |> redirect(to: ~p"/hub?auth=signup")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_flash(:error, registration_errors(changeset) |> Enum.join(". "))
        |> redirect(to: ~p"/hub?auth=signup")
    end
  end

  def create(conn, _params) do
    conn
    |> put_flash(:error, "Invalid signup payload")
    |> redirect(to: ~p"/hub?auth=signup")
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
