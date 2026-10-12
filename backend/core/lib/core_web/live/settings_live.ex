defmodule CoreWeb.SettingsLive do
  @moduledoc """
  Account settings for the signed-in user: name and username, GitHub login,
  email and password. Email and password changes need the current password.
  """
  use CoreWeb, :live_view

  alias Core.Accounts
  alias Core.Accounts.{Scope, User}

  @impl true
  def mount(_params, session, socket) do
    user = socket.assigns.current_scope.user

    {:ok,
     socket
     # This browser's session token: kept when signing out other sessions.
     # Never rendered.
     |> assign(page_title: "Account settings", session_token: session["user_token"])
     |> assign_forms(user)}
  end

  @impl true
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

  defp initials(user) do
    (user.full_name || user.username || user.email)
    |> String.split(~r/[\s_.@-]+/, trim: true)
    |> Enum.take(2)
    |> Enum.map_join("", &String.first/1)
    |> String.upcase()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <main class="mx-auto max-w-4xl px-4 pb-16 pt-10 sm:px-6">
        <div class="flex items-center gap-4">
          <span
            aria-hidden="true"
            class="inline-flex h-14 w-14 shrink-0 items-center justify-center rounded-2xl bg-[var(--hub-primary)] text-lg font-semibold text-white"
          >
            <%= initials(@user) %>
          </span>
          <div class="min-w-0">
            <p class="text-xs font-semibold uppercase tracking-[0.2em] text-[var(--hub-accent-2)]">Account settings</p>
            <h1 class="font-display mt-1 truncate text-3xl text-[var(--hub-text)]">
              <%= @user.full_name || @user.username %>
            </h1>
            <p class="truncate text-sm text-[var(--hub-muted)]"><%= @user.email %></p>
          </div>
        </div>

        <div class="mt-8 grid gap-5 md:grid-cols-2">
          <.settings_card title="Profile" description="How your name appears across IziHub.">
            <.form for={@profile_form} id="profile-form" phx-submit="save_profile" class="space-y-3">
              <.field form={@profile_form} field={:full_name} label="Full name" autocomplete="name" />
              <.field form={@profile_form} field={:username} label="Username" autocomplete="username" />
              <.save_button>Save profile</.save_button>
            </.form>
          </.settings_card>

          <.settings_card
            title="Connected accounts"
            description="Your public GitHub username, for the hub's Developer card. Leave blank to unlink."
          >
            <.form for={@github_form} id="github-form" phx-submit="save_github" class="space-y-3">
              <.field form={@github_form} field={:github_username} label="GitHub username" placeholder="octocat" />
              <.save_button>Save GitHub</.save_button>
            </.form>
          </.settings_card>

          <.settings_card title="Email" description="Used to sign in. A new address starts unverified.">
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
            description="Sign-ins last 60 days. Changing your password also signs out every other device."
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
  attr :description, :string, required: true
  slot :inner_block, required: true

  defp settings_card(assigns) do
    ~H"""
    <section class="hub-glass rounded-2xl p-5">
      <h2 class="font-display text-lg text-[var(--hub-text)]"><%= @title %></h2>
      <p class="mt-1 text-sm text-[var(--hub-muted)]"><%= @description %></p>
      <div class="mt-4"><%= render_slot(@inner_block) %></div>
    </section>
    """
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
