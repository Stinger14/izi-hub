defmodule CoreWeb.NotebooksLive do
  use CoreWeb, :live_view

  alias Core.Notebooks

  def mount(_params, _session, socket) do
    {:ok, assign(socket, current_scope: nil, notebooks: [], notebook: nil, error: nil)}
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
    <div class="min-h-screen bg-slate-900/40 px-6 py-16">
    <div class="mx-auto flex min-h-[calc(100vh-8rem)] items-start justify-center">
    <div class="w-full max-w-4xl rounded-2xl border border-amber-200 bg-amber-50 p-6 shadow-xl">
    <div class="flex items-center justify-between">
    <div class="flex items-center gap-2 text-xs font-semibold uppercase tracking-wide text-
    amber-700">
    <span>Notebooks</span>
    <span class="text-amber-600">Library</span>
    </div>
    <a href={~p"/"} class="text-xs text-amber-700 hover:text-amber-800">Back home</a>
    </div>

    <%= if @error do %>
    <div class="mt-4 rounded-lg border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-
    700">
    <%= @error %>
    </div>
    <% end %>

    <%= if @live_action == :index do %>
    <div class="mt-6 grid gap-4 sm:grid-cols-2">
    <%= for notebook <- @notebooks do %>
    <a
    href={~p"/notebooks/#{notebook.slug}"}
    class="rounded-xl border border-amber-200 bg-white p-4 text-left shadow-sm
    hover:border-amber-300"
    ><p class="text-sm font-semibold text-slate-900"><%= notebook.slug %></p>
                    <p class="mt-1 text-xs text-slate-600">Open notebook</p>
                  </a>
                <% end %>
              </div>
            <% else %>
              <div class="mt-6 rounded-xl border border-amber-200 bg-white shadow-inner">
                <div class="flex items-center gap-3 border-b border-amber-200 bg-amber-100 px-4 py-2">
                  <div class="flex items-center gap-1">
                    <span class="h-4 w-2 rounded-sm bg-amber-300"></span>
                    <span class="h-4 w-2 rounded-sm bg-rose-300"></span>
                    <span class="h-4 w-2 rounded-sm bg-indigo-300"></span>
                    <span class="h-4 w-2 rounded-sm bg-emerald-300"></span>
                  </div>
                  <span class="text-xs font-mono text-amber-900"><%= @notebook.slug %></span>
                  <a href={~p"/notebooks"} class="ml-auto text-xs text-amber-700 hover:text-amber-800">
                    Back to list
                  </a>
                </div>

                <div class="prose max-w-none px-6 py-6">
                  <%= raw(@notebook.html) %>
                </div>
              </div>
            <% end %>

            <div class="mt-4 text-xs text-amber-700">
              Source: GitHub <span class="font-semibold text-amber-800">priv/notebooks</span>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
