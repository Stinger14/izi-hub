defmodule CoreWeb.NotebooksLive do
  use CoreWeb, :live_view

  alias Core.Notebooks

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign_new(:current_scope, fn -> nil end)
     |> assign(
       notebooks: [],
       livebook_apps: [],
       books: [],
       notebook: nil,
       error: nil
     )}
  end

  def handle_params(params, _uri, socket) do
    case socket.assigns.live_action do
      :index ->
        {notebooks, notebooks_error} = collection_result(Notebooks.list_notebooks())
        {livebook_apps, livebook_error} = collection_result(Notebooks.list_livebook_apps())
        {books, books_error} = collection_result(Notebooks.list_books())

        error =
          [notebooks_error, livebook_error, books_error]
          |> Enum.reject(&is_nil/1)
          |> Enum.join(" · ")
          |> case do
            "" -> nil
            message -> message
          end

        {:noreply,
         assign(socket,
           notebooks: notebooks,
           livebook_apps: livebook_apps,
           books: books,
           notebook: nil,
           error: error
         )}

      :show ->
        slug = params["slug"]

        case Notebooks.fetch_notebook(slug) do
          {:ok, notebook} ->
            {:noreply, assign(socket, notebook: notebook, error: nil)}

          {:error, reason} ->
            {:noreply, assign(socket, notebook: nil, error: inspect(reason))}
        end
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="min-h-screen">
        <header class="border-b border-[color:var(--hub-border)]">
          <div class="mx-auto flex max-w-6xl items-center justify-between px-6 py-5">
            <div>
              <p class="font-display text-lg text-[var(--hub-accent-2)]">Notebooks</p>
            </div>
            <a
              href={~p"/hub"}
              class="btn btn-secondary btn-sm"
            >
              Back home
            </a>
          </div>
        </header>

        <main class="mx-auto max-w-6xl px-6 pb-16 pt-12">
          <div class="flex flex-col gap-6 lg:flex-row lg:items-start lg:justify-between">
            <div>
              <p class="text-sm font-medium text-[var(--hub-accent-2)]">Your library</p>
              <h1 class="font-display mt-3 text-3xl text-[var(--hub-text)] sm:text-4xl">
                Books &amp; notebooks
              </h1>
              <p class="mt-3 text-sm text-[var(--hub-muted)]">
                PDF books and Livebook material are kept in separate collections.
              </p>
            </div>
            <div class="flex flex-wrap items-center gap-3">
              <a
                href={~p"/notebooks"}
                class="btn btn-secondary btn-sm"
              >
                Refresh list
              </a>
            </div>
          </div>

          <%= if @error do %>
            <div class={["mt-6 rounded-2xl border border-[color:var(--tone-expense)]/30 px-4 py-3 text-sm", CoreWeb.FinanceComponents.tone_class("expense", :soft)]}>
              <%= @error %>
            </div>
          <% end %>

          <%= if @live_action == :index do %>
            <section class="mt-10" aria-labelledby="books-heading">
              <div class="flex items-end justify-between gap-3 border-b border-[color:var(--hub-border)] pb-3">
                <div><p class="text-[10px] font-semibold uppercase tracking-[0.16em] text-[var(--hub-accent-2)]">PDF library</p><h2 id="books-heading" class="font-display mt-1 text-xl text-[var(--hub-text)]">Books</h2></div>
                <span class="rounded-full border border-[color:var(--hub-border)] bg-[var(--hub-surface)] px-2.5 py-1 text-xs text-[var(--hub-muted)]"><%= length(@books) %> books</span>
              </div>
              <%= if @books == [] do %>
                <div class="hub-glass mt-4 rounded-xl px-5 py-6 text-sm text-[var(--hub-muted)]">No PDF books have been added yet.</div>
              <% else %>
                <div class="mt-4 grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
                  <a :for={book <- @books} href={~p"/books/#{book.slug}"} class="group flex min-w-0 items-center gap-3 hub-glass hub-glass-interactive rounded-xl p-4 hover:-translate-y-0.5">
                    <span class="inline-flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-[color:var(--hub-accent)]/15 text-[10px] font-bold uppercase text-[var(--hub-accent-2)]">PDF</span>
                    <span class="min-w-0 flex-1"><span class="block truncate text-sm font-semibold text-[var(--hub-text)]"><%= book.title %></span><span class="mt-1 block text-xs text-[var(--hub-muted)]">Open book</span></span>
                    <.icon name="hero-arrow-right" class="h-4 w-4 shrink-0 text-[var(--hub-secondary)] transition group-hover:translate-x-0.5" />
                  </a>
                </div>
              <% end %>
            </section>

            <section class="mt-10" aria-labelledby="livebooks-heading">
              <div class="border-b border-[color:var(--hub-border)] pb-3"><p class="text-[10px] font-semibold uppercase tracking-[0.16em] text-[var(--hub-accent-2)]">Interactive notebooks</p><h2 id="livebooks-heading" class="font-display mt-1 text-xl text-[var(--hub-text)]">Livebook notebooks</h2></div>
              <%= if @livebook_apps == [] do %>
                <div class="hub-glass mt-4 rounded-xl px-5 py-6 text-sm text-[var(--hub-muted)]">No Livebook notebooks are available yet.</div>
              <% else %>
                <div class="mt-4 grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
                  <%= for app <- @livebook_apps do %>
                    <%= if app.url do %>
                      <a href={app.url} target="_blank" rel="noreferrer" class="group hub-glass hub-glass-interactive rounded-xl p-4 hover:-translate-y-0.5">
                        <p class="text-[10px] font-semibold uppercase tracking-[0.16em] text-[var(--hub-accent-2)]">Livebook</p><p class="mt-2 text-sm font-semibold text-[var(--hub-text)]"><%= app.title %></p><p class="mt-1 text-xs leading-relaxed text-[var(--hub-muted)]"><%= app.description %></p>
                      </a>
                    <% else %>
                      <article class="rounded-xl border border-dashed border-[color:var(--hub-border)] bg-[var(--hub-surface)] p-4">
                        <p class="text-xs font-semibold uppercase tracking-wide text-[var(--hub-muted)]">Livebook</p><p class="mt-2 text-sm font-semibold text-[var(--hub-text)]"><%= app.title %></p><p class="mt-1 text-xs leading-relaxed text-[var(--hub-muted)]"><%= app.description %></p><p class={["mt-3 text-xs", CoreWeb.FinanceComponents.tone_class("review", :text)]}>App URL not configured.</p>
                      </article>
                    <% end %>
                  <% end %>
                </div>
              <% end %>
            </section>

            <section class="mt-10" aria-labelledby="previews-heading">
              <div class="border-b border-[color:var(--hub-border)] pb-3"><p class="text-[10px] font-semibold uppercase tracking-[0.16em] text-[var(--hub-accent-2)]">Markdown</p><h2 id="previews-heading" class="font-display mt-1 text-xl text-[var(--hub-text)]">Notebook previews</h2></div>
              <%= if @notebooks == [] do %>
                <div class="hub-glass mt-4 rounded-xl px-5 py-6 text-sm text-[var(--hub-muted)]">No notebook previews are available yet.</div>
              <% else %>
                <div class="mt-4 grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
                  <a :for={notebook <- @notebooks} href={~p"/notebooks/#{notebook.slug}"} class="hub-glass hub-glass-interactive rounded-xl p-4 hover:-translate-y-0.5">
                    <p class="text-xs font-semibold uppercase tracking-wide text-[var(--hub-muted)]">Notebook preview</p><p class="mt-2 text-sm font-semibold text-[var(--hub-text)]"><%= notebook.slug %></p><p class="mt-1 text-xs text-[var(--hub-secondary)]">Open preview</p>
                  </a>
                </div>
              <% end %>
            </section>
          <% else %>
            <%= if @notebook do %>
              <div class="hub-glass mt-10 rounded-2xl">
                <div class="flex flex-wrap items-center gap-3 border-b border-[color:var(--hub-border)] px-6 py-4">
                  <p class="text-xs font-semibold uppercase tracking-wide text-[var(--hub-muted)]">Preview</p>
                  <span class="text-sm font-semibold text-[var(--hub-text)]"><%= @notebook.slug %></span>
                  <a
                    href={~p"/notebooks"}
                    class="btn btn-secondary btn-sm ml-auto"
                  >
                    Back to list
                  </a>
                </div>
                <div class="prose prose-invert max-w-none px-6 py-8 prose-a:text-[var(--hub-secondary)] prose-code:text-[var(--hub-accent-2)]">
                  <%= raw(@notebook.html) %>
                </div>
              </div>
            <% else %>
              <div class="hub-glass mt-10 rounded-2xl px-6 py-8 text-sm text-[var(--hub-muted)]">
                Notebook preview not available.
              </div>
            <% end %>
          <% end %>

          <div class="mt-6 text-xs text-[var(--hub-muted)]">
            Source: GitHub <span class="font-semibold text-[var(--hub-text)]">priv/notebooks</span>
          </div>
        </main>
      </div>
    </Layouts.app>
    """
  end

  defp collection_result({:ok, items}), do: {items, nil}
  defp collection_result({:error, reason}), do: {[], inspect(reason)}
end
