defmodule CoreWeb.Layouts do
  @moduledoc """
  The page shell: the sticky header (wordmark, workspace nav, account menu),
  toasts and the footer, shared by LiveViews and controller pages.

  Context: `layouts/app.html.heex` uses these components. Pages pass
  `workspace={:hub | :office | :finance | :admin}` to highlight their app, and
  can add `<:workspace_tools>` chips and a `<:workspace_panel>` under the header.

  ## Example

      <Layouts.app flash={@flash} current_scope={@current_scope} workspace={:finance}>
        ...
      </Layouts.app>
  """

  use CoreWeb, :html

  import CoreWeb.FinanceComponents, only: [tone_class: 2]

  embed_templates "layouts/*"

  @doc """
  Toasts plus a "Reconnecting…" notice, fixed just below the header. Render it only
  from the layout.
  """
  attr :flash, :map, required: true

  def flash_group(assigns) do
    ~H"""
    <div
      id="flash-group"
      aria-live="polite"
      class="pointer-events-none fixed inset-x-4 top-[var(--flash-top,4.5rem)] z-[70] flex flex-col items-center gap-1.5"
    >
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <div
        id="client-reconnecting"
        hidden
        phx-disconnected={JS.show(to: "#client-reconnecting")}
        phx-connected={JS.hide(to: "#client-reconnecting")}
        role="status"
        class="hub-glass pointer-events-auto w-full max-w-md rounded-xl px-3 py-2 text-sm text-[var(--hub-text)]"
      >
        <span class="inline-flex items-center gap-2">
          <.icon name="hero-arrow-path" class="h-4 w-4 animate-spin text-[var(--hub-secondary)]" />
          Reconnecting…
        </span>
      </div>
    </div>
    """
  end

  @doc "App chips (Hub, Office, Finance, Admin for admins), page tool chips and the Pages menu."
  attr :current_scope, :map, required: true
  attr :active, :atom, default: nil
  slot :tools

  def workspace_nav(assigns) do
    assigns = assign(assigns, :apps, workspace_apps(assigns.current_scope))

    ~H"""
    <nav
      aria-label="Workspace"
      class="flex min-w-0 flex-1 items-center gap-1 overflow-x-auto rounded-xl bg-[var(--hub-bg)]/60 p-1 sm:gap-1.5"
    >
      <a
        :for={{key, label, icon, path} <- @apps}
        id={"workspace-nav-#{key}"}
        href={path}
        aria-current={if key == @active, do: "page"}
        aria-label={label}
        title={label}
        class={workspace_chip_class(key == @active)}
      >
        <.icon name={icon} class="h-4 w-4 text-[var(--hub-secondary)]" />
        <%!-- Phones show only the current app's name, so every app fits. --%>
        <span class={key != @active && "hidden sm:inline"}><%= label %></span>
      </a>
      <span :if={@tools != []} aria-hidden="true" class="mx-1 h-5 w-px shrink-0 bg-[var(--hub-border)]">
      </span>
      <%= render_slot(@tools) %>
    </nav>
    <details id="workspace-pages" class="relative shrink-0">
      <summary
        title="Pages"
        aria-label="Pages"
        class="inline-flex h-9 w-9 cursor-pointer list-none items-center justify-center rounded-lg border border-[color:var(--hub-border)] bg-[var(--hub-card)] text-[var(--hub-secondary)] transition hover:border-[color:var(--hub-accent)] focus:outline-none focus:ring-2 focus:ring-[color:var(--hub-accent)]/40"
      >
        <.icon name="hero-ellipsis-horizontal" class="h-4 w-4" />
      </summary>
      <div class={menu_panel_class()} style={menu_panel_style()}>
        <a
          :for={{label, path} <- page_links()}
          href={path}
          class={menu_item_class()}
        >
          <%= label %>
        </a>
      </div>
    </details>
    """
  end

  @doc """
  Photo or initials plus username, opening Settings and Sign out (pure JS, works on
  any page).
  """
  attr :user, :map, required: true

  def account_menu(assigns) do
    ~H"""
    <div
      class="relative shrink-0"
      phx-click-away={JS.hide(to: "#account-menu")}
      phx-window-keydown={JS.hide(to: "#account-menu")}
      phx-key="Escape"
    >
      <button
        type="button"
        id="account-menu-trigger"
        aria-haspopup="menu"
        aria-controls="account-menu"
        aria-label="Account menu"
        phx-click={JS.toggle(to: "#account-menu")}
        class="inline-flex h-9 items-center gap-2 rounded-lg border border-[color:var(--hub-border)] bg-[var(--hub-card)] pl-1 pr-1 text-xs font-semibold sm:pr-2 text-[var(--hub-text)] transition hover:border-[color:var(--hub-accent)] focus:outline-none focus:ring-2 focus:ring-[color:var(--hub-accent)]/40"
      >
        <.user_avatar user={@user} class="h-7 w-7 text-[10px]" />
        <span class="hidden max-w-[10rem] truncate sm:inline"><%= display_name(@user) %></span>
        <.icon name="hero-chevron-down" class="hidden h-3.5 w-3.5 text-[var(--hub-muted)] sm:block" />
      </button>
      <div id="account-menu" role="menu" class={["hidden", menu_panel_class()]} style={menu_panel_style()}>
        <a href={~p"/settings"} id="account-menu-settings" role="menuitem" class={menu_item_class()}>
          <.icon name="hero-cog-6-tooth" class="h-4 w-4 text-[var(--hub-secondary)]" />Settings
        </a>
        <.form for={%{}} as={:logout} action={~p"/logout"} method="delete">
          <button type="submit" id="account-menu-sign-out" role="menuitem" class={[menu_item_class(), "w-full"]}>
            <.icon name="hero-arrow-right-on-rectangle" class="h-4 w-4 text-[var(--hub-secondary)]" />Sign out
          </button>
        </.form>
      </div>
    </div>
    """
  end

  @doc "A user's profile photo, or their initials when they have none."
  attr :user, :map, required: true
  attr :class, :string, default: "h-8 w-8 text-xs"

  def user_avatar(assigns) do
    ~H"""
    <%= if @user.avatar_updated_at do %>
      <img
        src={avatar_path(@user)}
        alt=""
        class={["shrink-0 rounded-full object-cover", @class]}
      />
    <% else %>
      <span
        aria-hidden="true"
        class={[
          "inline-flex shrink-0 items-center justify-center rounded-full bg-[var(--hub-primary)] font-semibold text-white",
          @class
        ]}
      >
        <%= initials(@user) %>
      </span>
    <% end %>
    """
  end

  @doc "URL of a user's photo; the `?v=` version makes a new photo show at once."
  def avatar_path(user),
    do: ~p"/avatars/#{user.id}?v=#{DateTime.to_unix(user.avatar_updated_at)}"

  defp display_name(user), do: user.username || user.email

  defp initials(user) do
    (user.full_name || user.username || user.email)
    |> String.split([" ", "_", ".", "@", "-"], trim: true)
    |> Enum.take(2)
    |> Enum.map_join(&String.first/1)
    |> String.upcase()
  end

  # Menus nested in the header's glass: their own backdrop blur has nothing
  # to blur there, so keep them nearly opaque to stay readable.
  defp menu_panel_class do
    "hub-glass absolute right-0 top-full z-[60] mt-2 grid w-52 gap-1 rounded-xl p-2 shadow-[0_24px_40px_-20px_var(--hub-shadow)]"
  end

  defp menu_panel_style,
    do: "background-color: color-mix(in srgb, var(--hub-card) 97%, transparent);"

  defp menu_item_class do
    "inline-flex items-center gap-2 rounded-lg px-3 py-2 text-left text-sm font-medium text-[var(--hub-text)] transition hover:bg-[var(--hub-surface)] hover:text-[var(--hub-secondary)]"
  end

  @doc """
  Class for a header chip: `true` (active), `false` or `:disabled`. Pages use it for
  their tools.
  """
  def workspace_chip_class(:disabled) do
    "inline-flex h-8 shrink-0 cursor-not-allowed items-center gap-1.5 rounded-lg border border-transparent px-2.5 text-xs font-medium text-[var(--hub-muted)] opacity-70"
  end

  def workspace_chip_class(true) do
    "inline-flex h-8 shrink-0 items-center gap-1.5 rounded-lg border border-[color:var(--hub-accent)] bg-[color:var(--hub-accent)]/15 px-2.5 text-xs font-semibold text-[var(--hub-text)] transition"
  end

  def workspace_chip_class(false) do
    "inline-flex h-8 shrink-0 items-center gap-1.5 rounded-lg border border-[color:var(--hub-border)] bg-[var(--hub-card)] px-2.5 text-xs font-semibold text-[var(--hub-text)] transition hover:border-[color:var(--hub-accent)]"
  end

  defp workspace_apps(current_scope) do
    apps = [
      {:hub, "Hub", "hero-home", ~p"/hub"},
      {:office, "Office", "hero-calendar-days", ~p"/office"},
      {:finance, "Finance", "hero-banknotes", ~p"/finance"}
    ]

    if current_scope.user.role == "admin",
      do: apps ++ [{:admin, "Admin", "hero-shield-check", ~p"/admin"}],
      else: apps
  end

  defp page_links do
    [
      {"Dashboard", ~p"/hub"},
      {"Finance", ~p"/finance"},
      {"Books & notebooks", ~p"/notebooks"},
      {"Resources", ~p"/resources"},
      {"Live Apps", ~p"/liveapps"},
      {"Contributions", ~p"/contributions"},
      {"Profile", ~p"/profile"},
      {"Account settings", ~p"/settings"},
      {"Welcome", ~p"/welcome"}
    ]
  end

  attr :kind, :atom, values: [:info, :error], required: true
  attr :flash, :map, required: true

  defp flash(assigns) do
    assigns =
      assign(assigns,
        message: Phoenix.Flash.get(assigns.flash, assigns.kind),
        id: "flash-#{assigns.kind}"
      )

    ~H"""
    <div
      :if={@message}
      id={@id}
      data-flash
      data-flash-kind={@kind}
      data-flash-autodismiss={if @kind == :info, do: "5000"}
      phx-hook="Flash"
      role={if @kind == :error, do: "alert", else: "status"}
      class="hub-glass pointer-events-auto flex w-full max-w-md items-center gap-2.5 rounded-xl px-3 py-2 text-sm"
    >
      <span class={[
        "inline-flex h-5 w-5 shrink-0 items-center justify-center rounded-full",
        tone_class(if(@kind == :error, do: "expense", else: "income"), :soft)
      ]}>
        <.icon name={if @kind == :error, do: "hero-x-mark", else: "hero-check"} class="h-3 w-3" />
      </span>
      <p class="line-clamp-2 min-w-0 flex-1 leading-5 text-[var(--hub-text)]" title={@message}>
        <%= @message %>
      </p>
      <button
        type="button"
        data-flash-dismiss
        phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> JS.hide(to: "##{@id}")}
        aria-label="Dismiss message"
        class="-mr-1 shrink-0 rounded-md p-1 text-[var(--hub-muted)] transition hover:text-[var(--hub-text)]"
      >
        <.icon name="hero-x-mark" class="h-4 w-4" />
      </button>
    </div>
    """
  end
end
