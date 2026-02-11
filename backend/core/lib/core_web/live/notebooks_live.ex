defmodule CoreWeb.NotebooksLive do
  use CoreWeb, :live_view

  alias Core.Notebooks

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       current_scope: nil,
       notebooks: [],
       notebook: nil,
       error: nil
     )}
  end

  def handle_params(params, _uri, socket) do
    case socket.assigns.live_action do
      :index ->
        case Notebooks.list_notebooks() do
          {:ok, notebooks} ->
            {:noreply, assign(socket, notebooks: notebooks, notebook: nil, error: nil)}

          {:error, reason} ->
            {:noreply, assign(socket, notebooks: [], notebook: nil, error: inspect(reason))}
        end

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
              <p class="text-xs font-semibold uppercase tracking-wide text-purple-500">Notebooks</p>
              <p class="text-lg font-semibold tracking-tight text-slate-900">Notebook Library</p>
            </div>
            <a
              href={~p"/"}
              class="rounded-lg border border-purple-100 bg-white px-4 py-2 text-sm font-medium text-slate-700 transition-colors hover:bg-purple-300"
            >
              Back home
            </a>
          </div>
        </header>

        <main class="mx-auto max-w-6xl px-6 pb-16 pt-12">
          <div class="flex flex-col gap-6 lg:flex-row lg:items-start lg:justify-between">
            <div>
              <p class="text-sm font-medium text-purple-600">Preview markdown</p>
              <h1 class="mt-3 text-3xl font-semibold tracking-tight text-slate-900 sm:text-4xl">
                Explore API notebooks
              </h1>
              <p class="mt-3 text-sm text-slate-600">
                Browse markdown previews and keep a lightweight view of the notebook library.
              </p>
            </div>
            <div class="flex flex-wrap items-center gap-3">
              <a
                href={~p"/notebooks"}
                class="rounded-lg border border-purple-100 bg-white px-4 py-2 text-sm font-medium text-slate-700 transition-colors hover:bg-purple-300"
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
            <div class="mt-10 grid gap-6 md:grid-cols-2">
              <%= for notebook <- @notebooks do %>
                <a
                  href={~p"/notebooks/#{notebook.slug}"}
                  class="rounded-2xl border border-purple-100 bg-white/80 p-6 text-left shadow-sm hover:border-purple-200"
                >
                  <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Notebook</p>
                  <p class="mt-2 text-lg font-semibold text-slate-900"><%= notebook.slug %></p>
                  <p class="mt-2 text-sm text-slate-600">Open preview markdown</p>
                </a>
              <% end %>
            </div>
          <% else %>
            <%= if @notebook do %>
              <div class="mt-10 rounded-2xl border border-purple-100 bg-white/80 shadow-sm">
                <div class="flex flex-wrap items-center gap-3 border-b border-purple-100 bg-white/70 px-6 py-4">
                  <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Preview</p>
                  <span class="text-sm font-semibold text-slate-900"><%= @notebook.slug %></span>
                  <a
                    href={~p"/notebooks"}
                    class="ml-auto rounded-lg border border-purple-100 bg-white px-3 py-1.5 text-sm font-medium text-slate-700 transition-colors hover:bg-purple-300"
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
end
