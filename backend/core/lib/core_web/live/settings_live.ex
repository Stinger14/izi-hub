defmodule CoreWeb.SettingsLive do
  @moduledoc """
  `/settings`: the signed-in user's photo, name and username, GitHub login,
  email, password and other sessions.

  Context: each card has its own changeset; email and password changes need
  the current password. Photos upload as soon as they're picked and are
  checked by `Accounts.put_user_avatar/2`.
  """
  use CoreWeb, :live_view

  alias Core.Accounts
  alias Core.Accounts.{Scope, User}

  import CoreWeb.FinanceComponents, only: [tone_class: 2]

  @impl true
  def mount(_params, session, socket) do
    user = socket.assigns.current_scope.user

    {:ok,
     socket
     # This browser's session token: kept when signing out other sessions.
     # Never rendered.
     |> assign(page_title: "Account settings", session_token: session["user_token"])
     |> assign(avatar_error: nil)
     |> allow_upload(:avatar,
       accept: ~w(.jpg .jpeg .png .webp .gif),
       max_entries: 1,
       max_file_size: Accounts.avatar_max_bytes(),
       auto_upload: true,
       progress: &handle_progress/3
     )
     |> assign_forms(user)}
  end

  @impl true
  def handle_event("validate_avatar", _params, socket) do
    {:noreply, assign(socket, avatar_error: nil)}
  end

  def handle_event("remove_avatar", _params, socket) do
    {:ok, user} = Accounts.delete_user_avatar(current_user(socket))
    {:noreply, socket |> refresh_user(user) |> put_flash(:info, "Photo removed")}
  end

  def handle_event("save_profile", %{"profile" => params}, socket) do
    case Accounts.update_account_profile(current_user(socket), params) do
      {:ok, user} ->
        {:noreply, socket |> refresh_user(user) |> put_flash(:info, "Profile updated")}

      {:error, changeset} ->
        {:noreply, assign(socket, profile_form: to_form(changeset, as: :profile))}
    end
  end

  def handle_event("save_github", %{"github" => params}, socket) do
    case Accounts.update_github_username(current_user(socket), params) do
      {:ok, user} ->
        message =
          if user.github_username, do: "GitHub account linked", else: "GitHub account removed"

        {:noreply, socket |> refresh_user(user) |> put_flash(:info, message)}

      {:error, changeset} ->
        {:noreply, assign(socket, github_form: to_form(changeset, as: :github))}
    end
  end

  def handle_event("save_email", %{"email" => params}, socket) do
    {current_password, attrs} = Map.pop(params, "current_password")

    case Accounts.change_user_email(current_user(socket), current_password, attrs) do
      {:ok, user} ->
        {:noreply, socket |> refresh_user(user) |> put_flash(:info, "Email updated")}

      {:error, changeset} ->
        {:noreply, assign(socket, email_form: to_form(changeset, as: :email))}
    end
  end

  def handle_event("save_password", %{"password" => params}, socket) do
    {current_password, attrs} = Map.pop(params, "current_password")

    case Accounts.change_user_password(current_user(socket), current_password, attrs,
           except: socket.assigns.session_token
         ) do
      {:ok, user} ->
        {:noreply,
         socket
         |> refresh_user(user)
         |> put_flash(:info, "Password changed. Other devices have been signed out.")}

      {:error, changeset} ->
        {:noreply, assign(socket, password_form: to_form(changeset, as: :password))}
    end
  end

  def handle_event("sign_out_other_sessions", _params, socket) do
    count =
      Accounts.revoke_user_sessions(current_user(socket), except: socket.assigns.session_token)

    message =
      case count do
        0 -> "No other devices were signed in"
        1 -> "Signed out of 1 other device"
        n -> "Signed out of #{n} other devices"
      end

    {:noreply, put_flash(socket, :info, message)}
  end

  # Saves the photo once the browser has finished sending it.
  defp handle_progress(:avatar, %{done?: true} = entry, socket) do
    user = current_user(socket)

    result =
      consume_uploaded_entry(socket, entry, fn %{path: path} ->
        {:ok, Accounts.put_user_avatar(user, File.read!(path))}
      end)

    case result do
      {:ok, user} ->
        {:noreply, socket |> refresh_user(user) |> put_flash(:info, "Photo updated")}

      {:error, reason} ->
        {:noreply, assign(socket, avatar_error: avatar_error_message(reason))}
    end
  end

  defp handle_progress(:avatar, _entry, socket), do: {:noreply, socket}

  defp avatar_error_message(:too_large), do: "That image is over 2 MB."
  defp avatar_error_message(:not_accepted), do: "Use a JPEG, PNG, GIF or WebP image."
  defp avatar_error_message(:invalid_image), do: "That file isn't a JPEG, PNG, GIF or WebP image."
  defp avatar_error_message(:too_many_files), do: "Pick one image."
  defp avatar_error_message(_reason), do: "That image couldn't be uploaded."

  defp current_user(socket), do: socket.assigns.current_scope.user

  # Saving one card resets every form from the saved user, so the header
  # chip and the other cards show the new values.
  defp refresh_user(socket, %User{} = user) do
    socket
    |> assign(current_scope: Scope.for_user(user))
    |> assign_forms(user)
  end

  defp assign_forms(socket, user) do
    assign(socket,
      user: user,
      profile_form: to_form(User.account_profile_changeset(user, %{}), as: :profile),
      github_form: to_form(User.github_username_changeset(user, %{}), as: :github),
      email_form: to_form(%{"email" => user.email}, as: :email),
      password_form: to_form(%{}, as: :password)
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <main class="mx-auto max-w-4xl px-4 pb-16 pt-10 sm:px-6">
        <div class="flex items-center gap-4">
          <form id="avatar-form" phx-change="validate_avatar" phx-submit="validate_avatar" class="relative shrink-0">
            <Layouts.user_avatar user={@user} class="h-20 w-20 text-2xl" />
            <label
              for={@uploads.avatar.ref}
              id="avatar-upload"
              title="Change photo"
              class="absolute -bottom-1 -right-1 inline-flex h-8 w-8 cursor-pointer items-center justify-center rounded-full border border-[color:var(--hub-border)] bg-[var(--hub-card)] text-[var(--hub-secondary)] shadow transition hover:border-[color:var(--hub-accent)] focus-within:ring-2 focus-within:ring-[color:var(--hub-accent)]/40"
            >
              <span class="sr-only">Change photo</span>
              <.icon name="hero-camera" class="h-4 w-4" />
              <.live_file_input upload={@uploads.avatar} class="sr-only" />
            </label>
          </form>
          <div class="min-w-0">
            <h1 class="font-display truncate text-3xl text-[var(--hub-text)]">
              <%= @user.full_name || @user.username %>
            </h1>
            <p class="truncate text-sm text-[var(--hub-muted)]"><%= @user.email %></p>
            <button
              :if={@user.avatar_updated_at}
              type="button"
              id="avatar-remove"
              phx-click="remove_avatar"
              class="mt-1 inline-flex items-center gap-1 text-xs font-semibold text-[var(--hub-secondary)] transition hover:text-[var(--hub-text)]"
            >
              <.icon name="hero-trash" class="h-3.5 w-3.5" />Remove photo
            </button>
          </div>
        </div>
        <div :if={avatar_errors(@uploads.avatar, @avatar_error) != []} id="avatar-error" role="alert" class={["mt-3 text-sm", tone_class("expense", :text)]}>
          <p :for={message <- avatar_errors(@uploads.avatar, @avatar_error)}><%= message %></p>
        </div>

        <div class="mt-8 grid gap-5 md:grid-cols-2">
          <.settings_card title="Profile">
            <.form for={@profile_form} id="profile-form" phx-submit="save_profile" class="space-y-3">
              <.field form={@profile_form} field={:full_name} label="Full name" autocomplete="name" />
              <.field form={@profile_form} field={:username} label="Username" autocomplete="username" />
              <.save_button>Save profile</.save_button>
            </.form>
          </.settings_card>

          <.settings_card title="GitHub" description="Leave blank to unlink.">
            <.form for={@github_form} id="github-form" phx-submit="save_github" class="space-y-3">
              <.field form={@github_form} field={:github_username} label="GitHub username" placeholder="octocat" />
              <.save_button>Save GitHub</.save_button>
            </.form>
          </.settings_card>

          <.settings_card title="Email" description="A new address starts unverified.">
            <.form for={@email_form} id="email-form" phx-submit="save_email" class="space-y-3">
              <.field form={@email_form} field={:email} label="Email" type="email" autocomplete="email" />
              <.field
                form={@email_form}
                field={:current_password}
                label="Current password"
                type="password"
                autocomplete="current-password"
              />
              <.save_button>Change email</.save_button>
            </.form>
          </.settings_card>

          <.settings_card title="Password" description="At least 8 characters, with upper and lower case letters and a digit.">
            <.form for={@password_form} id="password-form" phx-submit="save_password" class="space-y-3">
              <.field
                form={@password_form}
                field={:current_password}
                label="Current password"
                type="password"
                autocomplete="current-password"
              />
              <.field form={@password_form} field={:password} label="New password" type="password" autocomplete="new-password" />
              <.field
                form={@password_form}
                field={:password_confirmation}
                label="Confirm new password"
                type="password"
                autocomplete="new-password"
              />
              <.save_button>Change password</.save_button>
            </.form>
          </.settings_card>

          <.settings_card
            title="Signed-in devices"
            description="Changing your password also signs out every other device."
          >
            <div class="flex justify-end">
              <button
                type="button"
                id="sign-out-other-sessions"
                phx-click="sign_out_other_sessions"
                phx-disable-with="Signing out…"
                class="btn btn-secondary btn-sm"
              >
                Sign out everywhere else
              </button>
            </div>
          </.settings_card>
        </div>
      </main>
    </Layouts.app>
    """
  end

  attr :title, :string, required: true
  attr :description, :string, default: nil
  slot :inner_block, required: true

  defp settings_card(assigns) do
    ~H"""
    <section class="hub-glass rounded-2xl p-5">
      <h2 class="font-display text-lg text-[var(--hub-text)]"><%= @title %></h2>
      <p :if={@description} class="mt-1 text-sm text-[var(--hub-muted)]"><%= @description %></p>
      <div class="mt-4"><%= render_slot(@inner_block) %></div>
    </section>
    """
  end

  # Upload-level errors (wrong type, too large, too many) plus the server's
  # verdict on the bytes, as one message list.
  defp avatar_errors(upload, server_error) do
    entry_errors = Enum.flat_map(upload.entries, &upload_errors(upload, &1))

    (upload_errors(upload) ++ entry_errors)
    |> Enum.map(&avatar_error_message/1)
    |> Kernel.++(List.wrap(server_error))
    |> Enum.uniq()
  end

  attr :form, :any, required: true
  attr :field, :atom, required: true
  attr :label, :string, required: true
  attr :type, :string, default: "text"
  attr :rest, :global, include: ~w(autocomplete placeholder)

  defp field(assigns) do
    f = assigns.form[assigns.field]
    # password values are never sent back to the browser
    value = if assigns.type == "password", do: nil, else: f.value
    assigns = assign(assigns, f: f, errors: f.errors, value: value)

    ~H"""
    <label class="block">
      <span class="mb-1 block text-[11px] font-semibold uppercase tracking-wide text-[var(--hub-muted)]"><%= @label %></span>
      <input
        type={@type}
        id={@f.id}
        name={@f.name}
        value={@value}
        aria-invalid={@errors != [] && "true"}
        class={[
          "w-full rounded-xl border bg-[var(--hub-surface)] px-3 py-2 text-sm text-[var(--hub-text)] outline-none focus:border-[color:var(--hub-accent)]",
          if(@errors == [], do: "border-[color:var(--hub-border)]", else: "border-[color:var(--tone-expense)]")
        ]}
        {@rest}
      />
      <span :for={error <- @errors} class="mt-1 block text-xs text-[var(--tone-expense)]">
        <%= @label %> <%= translate_error(error) %>
      </span>
    </label>
    """
  end

  # Only fills placeholders the message uses: some opts (like the uniqueness
  # check's `fields: [...]`) aren't strings.
  defp translate_error({message, opts}) do
    Regex.replace(~r/%{(\w+)}/, message, fn whole, key ->
      opts |> Keyword.get(String.to_existing_atom(key), whole) |> to_string()
    end)
  end

  slot :inner_block, required: true

  defp save_button(assigns) do
    ~H"""
    <div class="flex justify-end pt-1">
      <button type="submit" phx-disable-with="Saving…" class="btn btn-primary btn-sm"><%= render_slot(@inner_block) %></button>
    </div>
    """
  end
end
