defmodule Core.AdminOps do
  import Ecto.Query, warn: false

  alias Core.{Accounts, Analytics, Repo}
  alias Core.Accounts.UserToken
  alias Core.Analytics.PageView

  @cv_download_path "/cv/download"

  @type actor :: %{id: binary(), email: String.t()}

  @type op_id ::
          :promote_user_admin
          | :demote_user_admin
          | :activate_user
          | :deactivate_user
          | :generate_setup_password_link
          | :invalidate_user_tokens
          | :cleanup_expired_tokens
          | :cleanup_old_page_views
          | :reset_cv_downloads

  @operations [
    %{
      id: :promote_user_admin,
      label: "Promote User to Admin",
      description: "Set role to admin and activate the user.",
      risk: :sensitive,
      params: [:email],
      confirm_phrase: "PROMOTE"
    },
    %{
      id: :demote_user_admin,
      label: "Demote Admin to User",
      description: "Set role from admin to user.",
      risk: :sensitive,
      params: [:email],
      confirm_phrase: "DEMOTE"
    },
    %{
      id: :activate_user,
      label: "Activate User",
      description: "Set user as active.",
      risk: :safe,
      params: [:email],
      confirm_phrase: nil
    },
    %{
      id: :deactivate_user,
      label: "Deactivate User",
      description: "Set user as inactive.",
      risk: :destructive,
      params: [:email],
      confirm_phrase: "DEACTIVATE"
    },
    %{
      id: :generate_setup_password_link,
      label: "Generate Setup Password Link",
      description: "Create and return a setup password token for a user.",
      risk: :safe,
      params: [:email],
      confirm_phrase: nil
    },
    %{
      id: :invalidate_user_tokens,
      label: "Invalidate User Tokens",
      description: "Delete all auth/setup tokens for a user.",
      risk: :destructive,
      params: [:email],
      confirm_phrase: "INVALIDATE"
    },
    %{
      id: :cleanup_expired_tokens,
      label: "Cleanup Expired Tokens",
      description: "Delete all expired tokens.",
      risk: :destructive,
      params: [],
      confirm_phrase: "CLEANUP"
    },
    %{
      id: :cleanup_old_page_views,
      label: "Cleanup Old Page Views",
      description: "Delete analytics page views older than N days.",
      risk: :destructive,
      params: [:days_old],
      confirm_phrase: "CLEANUP"
    },
    %{
      id: :reset_cv_downloads,
      label: "Reset CV Downloads",
      description: "Delete all analytics entries for /cv/download.",
      risk: :destructive,
      params: [],
      confirm_phrase: "RESET_CV"
    }
  ]

  @spec list_operations() :: [map()]
  def list_operations, do: @operations

  @spec preview(op_id(), map(), actor()) :: {:ok, map()} | {:error, term()}
  def preview(op_id, params, actor) do
    with :ok <- validate_actor(actor),
         {:ok, operation} <- fetch_operation(op_id),
         {:ok, op_params} <- validate_params(operation, params, :preview),
         {:ok, result} <- do_preview(operation.id, op_params) do
      {:ok, Map.put(result, :operation, operation.id)}
    end
  end

  @spec run(op_id(), map(), actor()) :: {:ok, map()} | {:error, term()}
  def run(op_id, params, actor) do
    with :ok <- validate_actor(actor),
         {:ok, operation} <- fetch_operation(op_id),
         {:ok, op_params} <- validate_params(operation, params, :run),
         {:ok, result} <- do_run(operation.id, op_params) do
      {:ok, Map.put(result, :operation, operation.id)}
    end
  end

  defp do_preview(:promote_user_admin, %{email: email}) do
    with {:ok, user} <- fetch_user_by_email(email) do
      {:ok,
       %{
         summary: "User will be promoted to admin.",
         email: user.email,
         role_change: "#{user.role} -> admin",
         active_change: "#{user.is_active} -> true"
       }}
    end
  end

  defp do_preview(:demote_user_admin, %{email: email}) do
    with {:ok, user} <- fetch_user_by_email(email) do
      {:ok,
       %{
         summary: "User will be demoted to user.",
         email: user.email,
         role_change: "#{user.role} -> user"
       }}
    end
  end

  defp do_preview(:activate_user, %{email: email}) do
    with {:ok, user} <- fetch_user_by_email(email) do
      {:ok,
       %{
         summary: "User will be activated.",
         email: user.email,
         active_change: "#{user.is_active} -> true"
       }}
    end
  end

  defp do_preview(:deactivate_user, %{email: email}) do
    with {:ok, user} <- fetch_user_by_email(email) do
      {:ok,
       %{
         summary: "User will be deactivated.",
         email: user.email,
         active_change: "#{user.is_active} -> false"
       }}
    end
  end

  defp do_preview(:generate_setup_password_link, %{email: email}) do
    with {:ok, user} <- fetch_user_by_email(email) do
      {:ok,
       %{
         summary: "A new setup password link will be generated.",
         email: user.email,
         note: "Existing setup_password token will be replaced."
       }}
    end
  end

  defp do_preview(:invalidate_user_tokens, %{email: email}) do
    with {:ok, user} <- fetch_user_by_email(email) do
      token_count =
        from(t in UserToken, where: t.user_id == ^user.id)
        |> Repo.aggregate(:count)

      {:ok,
       %{
         summary: "All tokens for this user will be deleted.",
         email: user.email,
         tokens_to_delete: token_count
       }}
    end
  end

  defp do_preview(:cleanup_expired_tokens, _params) do
    count =
      from(t in UserToken, where: t.expires_at < ^now())
      |> Repo.aggregate(:count)

    {:ok,
     %{
       summary: "Expired tokens cleanup preview.",
       tokens_to_delete: count
     }}
  end

  defp do_preview(:cleanup_old_page_views, %{days_old: days_old}) do
    cutoff = cutoff_datetime(days_old)

    count =
      from(pv in PageView, where: pv.inserted_at < ^cutoff)
      |> Repo.aggregate(:count)

    {:ok,
     %{
       summary: "Old page views cleanup preview.",
       days_old: days_old,
       cutoff_date: NaiveDateTime.to_iso8601(cutoff),
       page_views_to_delete: count
     }}
  end

  defp do_preview(:reset_cv_downloads, _params) do
    count =
      cv_download_query()
      |> Repo.aggregate(:count)

    {:ok,
     %{
       summary: "CV download analytics will be reset.",
       cv_download_rows_to_delete: count
     }}
  end

  defp do_run(:promote_user_admin, %{email: email}) do
    with {:ok, user} <- fetch_user_by_email(email),
         {:ok, updated} <- apply_user_update(user, %{role: "admin", is_active: true}) do
      {:ok,
       %{
         summary: "User promoted to admin.",
         email: updated.email,
         role: updated.role,
         is_active: updated.is_active
       }}
    end
  end

  defp do_run(:demote_user_admin, %{email: email}) do
    with {:ok, user} <- fetch_user_by_email(email),
         {:ok, updated} <- apply_user_update(user, %{role: "user"}) do
      {:ok,
       %{
         summary: "User demoted to user role.",
         email: updated.email,
         role: updated.role
       }}
    end
  end

  defp do_run(:activate_user, %{email: email}) do
    with {:ok, user} <- fetch_user_by_email(email),
         {:ok, updated} <- apply_user_update(user, %{is_active: true}) do
      {:ok,
       %{
         summary: "User activated.",
         email: updated.email,
         is_active: updated.is_active
       }}
    end
  end

  defp do_run(:deactivate_user, %{email: email}) do
    with {:ok, user} <- fetch_user_by_email(email),
         {:ok, updated} <- apply_user_update(user, %{is_active: false}) do
      {:ok,
       %{
         summary: "User deactivated.",
         email: updated.email,
         is_active: updated.is_active
       }}
    end
  end

  defp do_run(:generate_setup_password_link, %{email: email}) do
    with {:ok, user} <- fetch_user_by_email(email) do
      token = Accounts.generate_setup_password_token(user)

      {:ok,
       %{
         summary: "Setup password link generated.",
         email: user.email,
         setup_path: "/set-password?token=#{token}"
       }}
    end
  end

  defp do_run(:invalidate_user_tokens, %{email: email}) do
    with {:ok, user} <- fetch_user_by_email(email) do
      {deleted_count, _} = Accounts.delete_user_tokens(user)

      {:ok,
       %{
         summary: "User tokens invalidated.",
         email: user.email,
         tokens_deleted: deleted_count
       }}
    end
  end

  defp do_run(:cleanup_expired_tokens, _params) do
    {deleted_count, _} = Accounts.delete_expired_tokens()

    {:ok,
     %{
       summary: "Expired tokens cleaned up.",
       tokens_deleted: deleted_count
     }}
  end

  defp do_run(:cleanup_old_page_views, %{days_old: days_old}) do
    {deleted_count, _} = Analytics.delete_old_page_views(days_old)

    {:ok,
     %{
       summary: "Old page views cleaned up.",
       days_old: days_old,
       page_views_deleted: deleted_count
     }}
  end

  defp do_run(:reset_cv_downloads, _params) do
    {deleted_count, _} =
      cv_download_query()
      |> Repo.delete_all()

    {:ok,
     %{
       summart: "CV download analytics reset",
       rows_deleted: deleted_count
     }}
  end

  defp validate_actor(%{id: id, email: email}) when is_binary(id) and is_binary(email), do: :ok
  defp validate_actor(_), do: {:error, :invalid_actor}

  defp fetch_operation(op_id) do
    case Enum.find(@operations, fn operation -> operation.id == op_id end) do
      nil -> {:error, :invalid_operation}
      operation -> {:ok, operation}
    end
  end

  defp validate_params(operation, params, mode) do
    params = normalize_params(params)

    with {:ok, email} <- extract_email(operation, params),
         {:ok, days_old} <- extract_days_old(operation, params),
         :ok <- validate_confirmation(operation, params, mode) do
      {:ok, %{email: email, days_old: days_old}}
    end
  end

  defp normalize_params(params) when is_map(params) do
    Enum.reduce(params, %{}, fn {key, value}, acc ->
      normalized_value =
        if is_binary(value) do
          String.trim(value)
        else
          value
        end

      Map.put(acc, to_string(key), normalized_value)
    end)
  end

  defp normalize_params(_params), do: %{}

  defp cv_download_query do
    from(pv in PageView, where: pv.page_path == ^@cv_download_path)
  end

  defp extract_email(operation, params) do
    if :email in operation.params do
      email = Map.get(params, "email", "")

      if email == "" do
        {:error, {:validation, "Email is required for this operation."}}
      else
        {:ok, email}
      end
    else
      {:ok, nil}
    end
  end

  defp extract_days_old(operation, params) do
    if :days_old in operation.params do
      raw_days_old = Map.get(params, "days_old", "90")

      case Integer.parse(raw_days_old) do
        {days_old, ""} when days_old > 0 and days_old <= 3650 ->
          {:ok, days_old}

        _ ->
          {:error, {:validation, "days_old must be a positive integer (1..3650)."}}
      end
    else
      {:ok, nil}
    end
  end

  defp validate_confirmation(operation, params, :run) do
    case operation.confirm_phrase do
      nil ->
        :ok

      phrase ->
        provided_phrase = Map.get(params, "confirm_text", "")

        if provided_phrase == phrase do
          :ok
        else
          {:error, {:validation, "Type #{phrase} in confirm_text to execute this operation."}}
        end
    end
  end

  defp validate_confirmation(_operation, _params, :preview), do: :ok

  defp fetch_user_by_email(email) do
    case Accounts.get_user_by_email(email) do
      nil -> {:error, {:not_found, "User not found for email: #{email}"}}
      user -> {:ok, user}
    end
  end

  defp apply_user_update(user, attrs) do
    user
    |> Ecto.Changeset.change(attrs)
    |> Repo.update()
  end

  defp now do
    NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
  end

  defp cutoff_datetime(days_old) do
    NaiveDateTime.add(now(), -days_old * 24 * 60 * 60, :second)
  end
end
