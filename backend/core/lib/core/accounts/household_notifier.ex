defmodule Core.Accounts.HouseholdNotifier do
  @moduledoc """
  Emails household invitation links.

  Context: called by `Core.Accounts.invite_to_household/4`. Sends in the
  background and only when a mailer is configured (`SMTP_*`); failures are
  logged, never fatal, because the inviter can always copy the link.
  """
  import Swoosh.Email
  require Logger

  alias Core.Accounts.HouseholdInvitation
  alias Core.Mailer

  @doc "Emails the invitation link in the background. `:ok`, or `:skipped` when no mailer is set."
  def deliver_invitation(%HouseholdInvitation{} = invitation, url) do
    inviter = inviter_name(invitation.invited_by)
    household = invitation.household.name

    email =
      new()
      |> to(invitation.email)
      |> from(Application.get_env(:core, :mail_from, {"IziHub", "no-reply@izihub.app"}))
      |> subject("#{inviter} invited you to #{household} on IziHub")
      |> text_body("""
      Hi,

      #{inviter} invited you to join the household "#{household}" on IziHub, to track
      shared accounts, budgets and spending together.

      Accept the invitation here (the link expires in 14 days):

      #{url}

      If you weren't expecting this, you can ignore this email.
      """)

    # Sent in the background so a slow SMTP server never holds up the page.
    if mailer_enabled?(), do: deliver_async(email, invitation), else: :skipped
  end

  defp deliver_async(email, invitation) do
    case Task.Supervisor.start_child(Core.TaskSupervisor, fn -> deliver(email, invitation) end) do
      {:ok, _pid} -> :ok
      {:error, reason} -> log_failure(invitation, reason)
    end
  catch
    # The task supervisor isn't running (e.g. a node started before it was
    # added); the invitation still stands and its link is shown to the inviter.
    :exit, reason -> log_failure(invitation, reason)
  end

  defp deliver(email, invitation) do
    case Mailer.deliver(email) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        log_failure(invitation, reason)
    end
  end

  defp log_failure(invitation, reason) do
    Logger.warning(
      "Household invitation email failed for invitation #{invitation.id}: #{inspect(reason)}"
    )

    :error
  end

  # Production without SMTP_HOST keeps the Local adapter but with its mailbox
  # storage disabled (`config :swoosh, local: false`), where delivering would
  # crash; there is nowhere to send it, so skip.
  defp mailer_enabled? do
    adapter = Application.get_env(:core, Mailer, [])[:adapter]
    adapter != Swoosh.Adapters.Local or Application.get_env(:swoosh, :local, true)
  end

  defp inviter_name(%{full_name: name}) when is_binary(name) and name != "", do: name
  defp inviter_name(%{username: name}) when is_binary(name) and name != "", do: name
  defp inviter_name(_user), do: "Someone"
end
