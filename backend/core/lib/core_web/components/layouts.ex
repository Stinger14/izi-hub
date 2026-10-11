defmodule CoreWeb.Layouts do
  use CoreWeb, :html

  import CoreWeb.FinanceComponents, only: [tone_class: 2]

  embed_templates "layouts/*"

  @doc """
  Flash messages plus a "reconnecting" notice, rendered once by the app
  layout on every page (LiveViews and controller-rendered pages alike).
  Only call this from the layout.
  """
  attr :flash, :map, required: true

  def flash_group(assigns) do
    ~H"""
    <div
      id="flash-group"
      aria-live="polite"
      class="pointer-events-none fixed inset-x-4 top-16 z-[70] flex flex-col items-end gap-2 sm:left-auto sm:right-6 sm:w-96"
    >
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <div
        id="client-reconnecting"
        hidden
        phx-disconnected={JS.show(to: "#client-reconnecting")}
        phx-connected={JS.hide(to: "#client-reconnecting")}
        role="status"
        class="hub-glass pointer-events-auto w-full rounded-xl px-4 py-3 text-sm text-[var(--hub-text)]"
      >
        <span class="inline-flex items-center gap-2">
          <.icon name="hero-arrow-path" class="h-4 w-4 animate-spin text-[var(--hub-secondary)]" />
          Reconnecting…
        </span>
      </div>
    </div>
    """
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
      class="hub-glass pointer-events-auto flex w-full items-start gap-3 rounded-xl px-4 py-3 text-sm"
    >
      <span class={[
        "mt-0.5 inline-flex h-6 w-6 shrink-0 items-center justify-center rounded-full",
        tone_class(if(@kind == :error, do: "expense", else: "income"), :soft)
      ]}>
        <.icon name={if @kind == :error, do: "hero-x-mark", else: "hero-check"} class="h-3.5 w-3.5" />
      </span>
      <p class="min-w-0 flex-1 leading-5 text-[var(--hub-text)]"><%= @message %></p>
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
