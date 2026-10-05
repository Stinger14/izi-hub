defmodule CoreWeb.HubComponents do
  @moduledoc """
  Dashboard widgets for `CoreWeb.HubLive`. Every widget is presentation-only
  and renders an empty state until its feature is wired up. Colors resolve
  through the `--hub-*` tokens scoped to `.hub-shell` (see `app.css`); the
  Finance card reuses `FinanceComponents.fin_card/1` and `tone_class/2`,
  which `.hub-shell` maps onto the hub palette.
  """
  use CoreWeb, :html

  import CoreWeb.FinanceComponents, only: [fin_card: 1, tone_class: 2]

  @stats_variants ~w(creator developer)

  def stats_variants, do: @stats_variants

  @doc "Base hub surface: walnut card, hairline border, soft shadow."
  attr :id, :string, default: nil
  attr :kicker, :string, required: true
  attr :title, :string, required: true
  attr :icon, :string, default: nil
  attr :class, :any, default: nil
  slot :actions
  slot :inner_block, required: true

  def hub_card(assigns) do
    ~H"""
    <section
      id={@id}
      class={[
        "hub-glass rounded-2xl border border-[color:var(--hub-border)] bg-[var(--hub-card)] p-4 shadow-[0_18px_36px_-26px_var(--hub-shadow)] sm:p-5",
        @class
      ]}
    >
      <div class="flex items-start justify-between gap-3">
        <div class="flex min-w-0 items-center gap-2.5">
          <span
            :if={@icon}
            class="inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-lg border border-[color:var(--hub-border)] bg-[var(--hub-surface)] text-[var(--hub-secondary)]"
          >
            <.icon name={@icon} class="h-4 w-4" />
          </span>
          <div class="min-w-0">
            <p class="text-[10px] font-semibold uppercase tracking-[0.16em] text-[var(--hub-accent-2)]">
              <%= @kicker %>
            </p>
            <h2 class="font-display truncate text-lg text-[var(--hub-text)]"><%= @title %></h2>
          </div>
        </div>
        <div :if={@actions != []} class="flex shrink-0 items-center gap-1">
          <%= render_slot(@actions) %>
        </div>
      </div>
      <div class="mt-4">
        <%= render_slot(@inner_block) %>
      </div>
    </section>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, default: "—"
  attr :hint, :string, default: nil

  defp hub_stat(assigns) do
    ~H"""
    <div class="min-w-0 rounded-xl border border-[color:var(--hub-border)] bg-[var(--hub-surface)] p-3">
      <p class="truncate text-[11px] text-[var(--hub-muted)]"><%= @label %></p>
      <p class="mt-1.5 text-lg font-semibold leading-none text-[var(--hub-text)]"><%= @value %></p>
      <p :if={@hint} class="mt-1.5 truncate text-[11px] text-[var(--hub-muted)]"><%= @hint %></p>
    </div>
    """
  end

  attr :current_scope, :any, default: nil

  def finance_card(assigns) do
    ~H"""
    <.fin_card class="hub-glass flex h-full flex-col">
      <div class="flex items-start justify-between gap-3">
        <div>
          <p class="text-[10px] font-semibold uppercase tracking-[0.16em] text-[var(--hub-accent-2)]">
            Finance
          </p>
          <h2 class="font-display text-2xl text-[var(--fin-text)]">Your money, at a glance</h2>
        </div>
        <span class={[
          "shrink-0 rounded-full px-2.5 py-1 text-[11px] font-semibold",
          tone_class("muted", :soft)
        ]}>
          Not connected
        </span>
      </div>
      <div class="mt-5 grid grid-cols-2 gap-3">
        <.hub_stat label="Balances" hint="Connect an account" />
        <.hub_stat label="Monthly spending" hint="No data yet" />
      </div>
      <div class="mt-auto pt-5">
        <a
          href={if @current_scope, do: ~p"/finance", else: ~p"/login"}
          class="inline-flex items-center gap-1 rounded-lg px-2 py-1.5 text-sm font-semibold text-[var(--fin-accent)] transition hover:bg-[var(--fin-surface)] hover:text-[var(--hub-primary)]"
        >
          Open Finance <.icon name="hero-arrow-right" class="h-4 w-4" />
        </a>
      </div>
    </.fin_card>
    """
  end

  attr :variant, :string, required: true, values: ~w(creator developer)
  attr :current_scope, :any, default: nil

  def role_stats_card(assigns) do
    ~H"""
    <section class="hub-glass flex h-full flex-col rounded-2xl border border-[color:var(--hub-border)] bg-[var(--hub-card)] p-5 shadow-[0_16px_32px_-24px_var(--hub-shadow)] sm:p-6">
      <div class="flex flex-wrap items-start justify-between gap-3">
        <div>
          <p class="text-[10px] font-semibold uppercase tracking-[0.16em] text-[var(--hub-accent-2)]">
            <%= if @variant == "creator", do: "Creator stats", else: "Developer stats" %>
          </p>
          <h2 class="font-display text-2xl text-[var(--hub-text)]">
            <%= if @variant == "creator", do: "Your reach", else: "Your code activity" %>
          </h2>
        </div>
        <div
          role="group"
          aria-label="Stats view"
          class="inline-flex rounded-lg border border-[color:var(--hub-border)] bg-[var(--hub-surface)] p-0.5"
        >
          <button
            :for={variant <- stats_variants()}
            type="button"
            phx-click="set_stats_variant"
            phx-value-variant={variant}
            aria-pressed={to_string(variant == @variant)}
            class={stats_toggle_class(variant == @variant)}
          >
            <%= String.capitalize(variant) %>
          </button>
        </div>
      </div>

      <%= if @variant == "creator" do %>
        <div class="mt-5 flex items-center gap-3 rounded-xl border border-dashed border-[color:var(--hub-border)] px-3 py-2.5">
          <span class="inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-[var(--hub-surface)] text-xs font-bold text-[var(--hub-muted)]">
            f
          </span>
          <div class="min-w-0">
            <p class="truncate text-sm font-semibold text-[var(--hub-text)]">Facebook account</p>
            <p class="text-[11px] text-[var(--hub-muted)]">Not connected</p>
          </div>
        </div>
        <div class="mt-3 grid grid-cols-3 gap-3">
          <.hub_stat label="Followers" hint="Growth —" />
          <.hub_stat label="Video views" />
          <.hub_stat label="Interactions" />
        </div>
      <% else %>
        <div class="mt-5 grid grid-cols-3 gap-3">
          <.hub_stat label="Repositories" />
          <.hub_stat label="Contributions" hint="Last 12 months" />
          <.hub_stat label="Last activity" />
        </div>
        <a
          :if={@current_scope}
          href={~p"/contributions"}
          class="mt-auto inline-flex items-center gap-1 self-start rounded-lg px-2 pt-5 text-sm font-semibold text-[var(--hub-secondary)] transition hover:text-[var(--hub-primary)]"
        >
          GitHub details <.icon name="hero-arrow-right" class="h-4 w-4" />
        </a>
      <% end %>
    </section>
    """
  end

  def tasks_panel(assigns) do
    ~H"""
    <.hub_card id="tasks" kicker="Focus" title="Tasks" icon="hero-check" class="h-full sm:p-6">
      <div class="flex items-center gap-3 rounded-xl border border-dashed border-[color:var(--hub-border)] px-4 py-6">
        <span class="inline-flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-[var(--hub-surface)] text-[var(--hub-secondary)]">
          <.icon name="hero-plus" class="h-4 w-4" />
        </span>
        <div>
          <p class="text-sm font-semibold text-[var(--hub-text)]">No tasks yet</p>
          <p class="mt-0.5 text-xs text-[var(--hub-muted)]">Your tasks will appear here.</p>
        </div>
      </div>
    </.hub_card>
    """
  end

  attr :month, Date, required: true
  attr :days, :list, required: true
  attr :weekdays, :list, required: true
  attr :selected_date, :any, default: nil

  def calendar_card(assigns) do
    ~H"""
    <.hub_card
      id="calendar"
      kicker="Calendar"
      title={Calendar.strftime(@month, "%B %Y")}
      icon="hero-calendar-days"
    >
      <:actions>
        <button
          type="button"
          phx-click="prev_calendar_month"
          aria-label="Previous month"
          class="grid h-8 w-8 place-items-center rounded-lg text-[var(--hub-secondary)] transition hover:bg-[var(--hub-surface)]"
        >
          <.icon name="hero-arrow-left" class="h-3.5 w-3.5" />
        </button>
        <button
          type="button"
          phx-click="next_calendar_month"
          aria-label="Next month"
          class="grid h-8 w-8 place-items-center rounded-lg text-[var(--hub-secondary)] transition hover:bg-[var(--hub-surface)]"
        >
          <.icon name="hero-arrow-right" class="h-3.5 w-3.5" />
        </button>
      </:actions>
      <div class="grid grid-cols-7 text-center text-[10px] font-semibold uppercase tracking-wide text-[var(--hub-muted)]">
        <span :for={weekday <- @weekdays}><%= weekday %></span>
      </div>
      <div class="mt-1 grid grid-cols-7">
        <button
          :for={day <- @days}
          type="button"
          phx-click="select_calendar_date"
          phx-value-date={Date.to_iso8601(day.date)}
          aria-pressed={to_string(day.selected?)}
          class={calendar_day_class(day)}
        >
          <%= day.label %>
        </button>
      </div>
      <p class="mt-2 border-t border-[color:var(--hub-border)] pt-2 text-[11px] text-[var(--hub-muted)]">
        <%= if @selected_date, do: Calendar.strftime(@selected_date, "%a, %b %-d"), else: "Select a date" %>
      </p>
    </.hub_card>
    """
  end

  def music_card(assigns) do
    ~H"""
    <.hub_card id="music" kicker="Listening" title="Music" icon="hero-musical-note">
      <div class="flex items-center gap-3">
        <div class="h-12 w-12 shrink-0 rounded-lg border border-[color:var(--hub-border)] bg-[linear-gradient(135deg,var(--hub-accent),var(--hub-surface))]">
        </div>
        <div class="min-w-0">
          <p class="truncate text-sm font-semibold text-[var(--hub-text)]">Nothing playing</p>
          <p class="text-[11px] text-[var(--hub-muted)]">Connect a music service</p>
        </div>
      </div>
      <div class="mt-3 h-1 overflow-hidden rounded-full bg-[var(--hub-surface)]"></div>
      <div class="mt-3 flex items-center justify-center gap-2">
        <button
          :for={{label, glyph} <- [{"Previous track", "⏮"}, {"Play", "▶"}, {"Next track", "⏭"}]}
          type="button"
          disabled
          aria-label={label}
          title="Music connection coming soon"
          class="grid h-9 w-9 cursor-not-allowed place-items-center rounded-full border border-[color:var(--hub-border)] text-sm text-[var(--hub-muted)] opacity-70"
        >
          <span aria-hidden="true"><%= glyph %></span>
        </button>
      </div>
    </.hub_card>
    """
  end

  attr :current_scope, :any, default: nil

  def library_shortcuts(assigns) do
    ~H"""
    <.hub_card id="library" kicker="Library" title="Books & courses" icon="hero-book-open">
      <div class="grid gap-2">
        <a
          href={if @current_scope, do: ~p"/notebooks", else: ~p"/login"}
          class="group flex items-center gap-3 rounded-xl border border-[color:var(--hub-border)] bg-[var(--hub-surface)] px-3 py-2.5 transition hover:border-[color:var(--hub-accent)]"
        >
          <.icon name="hero-book-open" class="h-4 w-4 shrink-0 text-[var(--hub-secondary)]" />
          <span class="min-w-0 flex-1">
            <span class="block text-sm font-semibold text-[var(--hub-text)]">Books</span>
            <span class="block text-[11px] text-[var(--hub-muted)]">PDF library &amp; notebooks</span>
          </span>
          <.icon
            name="hero-arrow-right"
            class="h-4 w-4 shrink-0 text-[var(--hub-muted)] transition group-hover:translate-x-0.5 group-hover:text-[var(--hub-secondary)]"
          />
        </a>
        <div class="flex items-center gap-3 rounded-xl border border-dashed border-[color:var(--hub-border)] px-3 py-2.5">
          <.icon name="hero-academic-cap" class="h-4 w-4 shrink-0 text-[var(--hub-muted)]" />
          <span class="min-w-0 flex-1">
            <span class="block text-sm font-semibold text-[var(--hub-text)]">Courses</span>
            <span class="block text-[11px] text-[var(--hub-muted)]">Track what you're learning</span>
          </span>
          <span class="shrink-0 rounded-full bg-[color:var(--hub-accent)]/20 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-[var(--hub-accent-2)]">
            Soon
          </span>
        </div>
      </div>
    </.hub_card>
    """
  end

  def gmail_preview(assigns) do
    ~H"""
    <.hub_card id="gmail" kicker="Inbox" title="Gmail" icon="hero-envelope">
      <ul class="space-y-2" aria-label="Inbox preview">
        <li
          :for={width <- ["w-3/4", "w-2/3", "w-1/2"]}
          class="flex items-center gap-3 rounded-lg px-1 py-1.5"
          aria-hidden="true"
        >
          <span class="h-7 w-7 shrink-0 rounded-full bg-[var(--hub-surface)]"></span>
          <span class="flex-1 space-y-1.5">
            <span class={["block h-2 rounded-full bg-[var(--hub-surface)]", width]}></span>
            <span class="block h-2 w-full rounded-full bg-[color:var(--hub-surface)]/60"></span>
          </span>
        </li>
      </ul>
      <p class="mt-3 border-t border-[color:var(--hub-border)] pt-2 text-[11px] text-[var(--hub-muted)]">
        Connect Gmail to preview recent mail.
      </p>
    </.hub_card>
    """
  end

  defp stats_toggle_class(true) do
    "rounded-md bg-[var(--hub-primary)] px-2.5 py-1 text-xs font-semibold text-[var(--hub-on-primary)]"
  end

  defp stats_toggle_class(false) do
    "rounded-md px-2.5 py-1 text-xs font-semibold text-[var(--hub-muted)] transition hover:text-[var(--hub-text)]"
  end

  defp calendar_day_class(day) do
    base = "grid h-8 w-full place-items-center rounded-lg text-xs leading-none transition-colors"

    cond do
      day.selected? ->
        base <> " bg-[var(--hub-primary)] font-semibold text-[var(--hub-on-primary)]"

      day.in_month? ->
        base <> " text-[var(--hub-text)] hover:bg-[var(--hub-surface)]"

      true ->
        base <> " text-[color:var(--hub-muted)]/40 hover:bg-[var(--hub-surface)]"
    end
  end
end
