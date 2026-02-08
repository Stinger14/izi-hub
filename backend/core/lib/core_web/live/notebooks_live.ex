defmodule CoreWeb.NotebooksLive do
  use CoreWeb, :live_view

  alias Core.Notebooks

  def mount(_params, session, socket) do
    livebook_admin = session["livebook_admin"] in [true, "true"]

    {:ok,
     assign(socket,
       current_scope: nil,
       notebooks: [],
       notebook: nil,
       error: nil,
       livebook_open: false,
       livebook_admin: livebook_admin,
       livebook_token_set: livebook_token_set?()
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

  def handle_event("toggle_livebook", _params, socket) do
    {:noreply, update(socket, :livebook_open, &(!&1))}
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
            <a href={~p"/"} class="text-sm text-slate-600 hover:text-slate-900">Back home</a>
          </div>
        </header>

        <main class="mx-auto max-w-6xl px-6 pb-16 pt-12">
          <div class="flex flex-col gap-6 lg:flex-row lg:items-start lg:justify-between">
            <div>
              <p class="text-sm font-medium text-purple-600">Preview markdown, run Livebook</p>
              <h1 class="mt-3 text-3xl font-semibold tracking-tight text-slate-900 sm:text-4xl">
                Explore and run API notebooks
              </h1>
              <p class="mt-3 text-sm text-slate-600">
                Browse markdown previews, then open Livebook inline without leaving the page.
              </p>
            </div>
            <div class="flex flex-wrap items-center gap-3">
              <button
                type="button"
                phx-click="toggle_livebook"
                class="rounded-lg bg-slate-900 px-4 py-2 text-sm font-medium text-purple-600 hover:bg-slate-800"
              >
                <%= if @livebook_open, do: "Close Livebook", else: "Open Livebook" %>
              </button>
              <a
                href={~p"/notebooks"}
                class="rounded-lg border border-purple-100 bg-white/80 px-4 py-2 text-sm font-medium text-purple-600 hover:border-purple-200"
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

          <%= if @livebook_open do %>
            <div class="mt-8 rounded-2xl border border-purple-100 bg-white/80 p-6 shadow-sm">
              <div class="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
                <div>
                  <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Livebook</p>
                  <p class="mt-1 text-sm text-slate-600">
                    Run notebooks on the same host with an authenticated session.
                  </p>
                </div>
                <%= if @livebook_admin do %>
                  <.form
                    for={to_form(%{}, as: :livebook)}
                    action={~p"/notebooks/livebook/access"}
                    method="delete"
                  >
                    <button
                      type="submit"
                      class="rounded-lg border border-purple-100 bg-white px-4 py-2 text-xs font-semibold text-slate-600 hover:border-purple-200"
                    >
                      Remove access
                    </button>
                  </.form>
                <% end %>
              </div>

              <%= if @livebook_admin do %>
                <div class="mt-6 overflow-hidden rounded-2xl border border-purple-100 bg-white">
                  <iframe
                    src="/livebook"
                    class="h-[620px] w-full"
                    title="Livebook"
                    loading="lazy"
                  ></iframe>
                </div>
              <% else %>
                <div class="mt-6 rounded-2xl border border-purple-100 bg-white p-5">
                  <p class="text-sm text-slate-600">
                    Livebook access is restricted.
                    <%= if @livebook_token_set do %>
                      Enter the admin token to enable it for this session.
                    <% else %>
                      An admin token has not been configured for this environment.
                    <% end %>
                  </p>

                  <%= if @livebook_token_set do %>
                    <.form
                      for={to_form(%{}, as: :livebook)}
                      action={~p"/notebooks/livebook/access"}
                      method="post"
                      class="mt-4 flex flex-col gap-3 sm:flex-row sm:items-center"
                    >
                      <input
                        type="password"
                        name="token"
                        autocomplete="current-password"
                        placeholder="Livebook admin token"
                        class="w-full rounded-lg border border-purple-100 bg-white px-3 py-2 text-sm text-slate-700 shadow-sm focus:border-purple-300 focus:outline-none"
                      />
                      <button
                        type="submit"
                        class="rounded-lg bg-slate-900 px-4 py-2 text-sm font-medium text-purple-600 hover:bg-slate-800"
                      >
                        Enable access
                      </button>
                    </.form>
                  <% end %>

                  <p class="mt-3 text-xs text-slate-500">
                    Set `LIVEBOOK_ADMIN_TOKEN` on the server to control access.
                  </p>
                </div>
              <% end %>
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
                    class="ml-auto text-sm font-medium text-purple-600 hover:text-purple-700"
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

  defp livebook_token_set? do
    case Core.Config.livebook_admin_token() do
      {:ok, token} when is_binary(token) -> String.trim(token) != ""
      _ -> false
    end
  end
end
