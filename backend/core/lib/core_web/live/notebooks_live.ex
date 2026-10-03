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
      <div class="min-h-screen bg-purple-50 text-slate-900">
        <header class="border-b border-purple-100 bg-white/70 backdrop-blur">
          <div class="mx-auto flex max-w-6xl items-center justify-between px-6 py-5">
            <div>
              <p class="text-lg font-semibold tracking-tight text-purple-500">Notebooks</p>
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
              <p class="text-sm font-medium text-purple-600">Your library</p>
              <h1 class="mt-3 text-3xl font-semibold tracking-tight text-slate-900 sm:text-4xl">
                Books &amp; notebooks
              </h1>
              <p class="mt-3 text-sm text-slate-600">
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
            <div class="mt-6 rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">
              <%= @error %>
            </div>
          <% end %>

          <%= if @live_action == :index do %>
            <section class="mt-10" aria-labelledby="books-heading">
              <div class="flex items-end justify-between gap-3 border-b border-purple-100 pb-3">
                <div><p class="text-xs font-semibold uppercase tracking-wide text-purple-600">PDF library</p><h2 id="books-heading" class="mt-1 text-xl font-semibold text-slate-900">Books</h2></div>
                <span class="rounded-full bg-purple-50 px-2.5 py-1 text-xs text-slate-500"><%= length(@books) %> books</span>
              </div>
              <%= if @books == [] do %>
                <div class="mt-4 rounded-xl border border-purple-100 bg-white/80 px-5 py-6 text-sm text-slate-500">No PDF books have been added yet.</div>
              <% else %>
                <div class="mt-4 grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
                  <a :for={book <- @books} href={~p"/books/#{book.slug}"} class="group flex items-center gap-3 rounded-xl border border-purple-100 bg-white p-4 shadow-sm transition hover:-translate-y-0.5 hover:border-purple-200 hover:shadow-md">
                    <span class="inline-flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-purple-50 text-[10px] font-bold uppercase text-purple-700">PDF</span>
                    <span class="min-w-0 flex-1"><span class="block truncate text-sm font-semibold text-slate-900"><%= book.title %></span><span class="mt-1 block text-xs text-slate-500">Open book</span></span>
                    <.icon name="hero-arrow-right" class="h-4 w-4 shrink-0 text-purple-500 transition group-hover:translate-x-0.5" />
                  </a>
                </div>
              <% end %>
            </section>

            <section class="mt-10" aria-labelledby="livebooks-heading">
              <div class="border-b border-purple-100 pb-3"><p class="text-xs font-semibold uppercase tracking-wide text-purple-600">Interactive notebooks</p><h2 id="livebooks-heading" class="mt-1 text-xl font-semibold text-slate-900">Livebook notebooks</h2></div>
              <%= if @livebook_apps == [] do %>
                <div class="mt-4 rounded-xl border border-purple-100 bg-white/80 px-5 py-6 text-sm text-slate-500">No Livebook notebooks are available yet.</div>
              <% else %>
                <div class="mt-4 grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
                  <%= for app <- @livebook_apps do %>
                    <%= if app.url do %>
                      <a href={app.url} target="_blank" rel="noreferrer" class="group rounded-xl border border-purple-100 bg-white p-4 shadow-sm transition hover:-translate-y-0.5 hover:border-purple-200 hover:shadow-md">
                        <p class="text-xs font-semibold uppercase tracking-wide text-purple-600">Livebook</p><p class="mt-2 text-sm font-semibold text-slate-900"><%= app.title %></p><p class="mt-1 text-xs leading-relaxed text-slate-500"><%= app.description %></p>
                      </a>
                    <% else %>
                      <article class="rounded-xl border border-dashed border-purple-200 bg-white/70 p-4">
                        <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Livebook</p><p class="mt-2 text-sm font-semibold text-slate-900"><%= app.title %></p><p class="mt-1 text-xs leading-relaxed text-slate-500"><%= app.description %></p><p class="mt-3 text-xs text-amber-700">App URL not configured.</p>
                      </article>
                    <% end %>
                  <% end %>
                </div>
              <% end %>
            </section>

            <section class="mt-10" aria-labelledby="previews-heading">
              <div class="border-b border-purple-100 pb-3"><p class="text-xs font-semibold uppercase tracking-wide text-purple-600">Markdown</p><h2 id="previews-heading" class="mt-1 text-xl font-semibold text-slate-900">Notebook previews</h2></div>
              <%= if @notebooks == [] do %>
                <div class="mt-4 rounded-xl border border-purple-100 bg-white/80 px-5 py-6 text-sm text-slate-500">No notebook previews are available yet.</div>
              <% else %>
                <div class="mt-4 grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
                  <a :for={notebook <- @notebooks} href={~p"/notebooks/#{notebook.slug}"} class="rounded-xl border border-purple-100 bg-white p-4 shadow-sm transition hover:-translate-y-0.5 hover:border-purple-200 hover:shadow-md">
                    <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Notebook preview</p><p class="mt-2 text-sm font-semibold text-slate-900"><%= notebook.slug %></p><p class="mt-1 text-xs text-purple-700">Open preview</p>
                  </a>
                </div>
              <% end %>
            </section>
          <% else %>
            <%= if @notebook do %>
              <div class="mt-10 rounded-2xl border border-purple-100 bg-white/80 shadow-sm">
                <div class="flex flex-wrap items-center gap-3 border-b border-purple-100 bg-white/70 px-6 py-4">
                  <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Preview</p>
                  <span class="text-sm font-semibold text-slate-900"><%= @notebook.slug %></span>
                  <a
                    href={~p"/notebooks"}
                    class="btn btn-secondary btn-sm ml-auto"
                  >
                    Back to list
                  </a>
                </div>
                <div class="prose prose-slate max-w-none px-6 py-8">
                  <%= raw(@notebook.html) %>
                </div>
              </div>
            <% else %>
              <div class="mt-10 rounded-2xl border border-purple-100 bg-white/80 px-6 py-8 text-sm text-slate-600">
                Notebook preview not available.
              </div>
            <% end %>
          <% end %>

          <div class="mt-6 text-xs text-slate-500">
            Source: GitHub <span class="font-semibold text-slate-700">priv/notebooks</span>
          </div>
        </main>
      </div>
    </Layouts.app>
    """
  end

  defp collection_result({:ok, items}), do: {items, nil}
  defp collection_result({:error, reason}), do: {[], inspect(reason)}
end
