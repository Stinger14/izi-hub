defmodule CoreWeb.NotebooksLive do
  use CoreWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, current_scope: nil)}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="min-h-screen bg-slate-900/40 px-6 py-16">
        <div class="mx-auto flex min-h-[calc(100vh-8rem)] items-center justify-center">
          <div class="w-full max-w-4xl rounded-2xl border border-amber-200 bg-amber-50 p-6 shadow-xl">
            <div class="flex items-center justify-between">
              <div class="flex items-center gap-2 text-xs font-semibold uppercase tracking-wide text-amber-700">
                <span>Notebooks</span>
                <span class="text-amber-600">Library</span>
              </div>
              <a href={~p"/"} class="text-xs text-amber-700 hover:text-amber-800">Back home</a>
            </div>

            <div class="mt-4 rounded-xl border border-amber-200 bg-white shadow-inner">
              <div class="flex items-center gap-3 border-b border-amber-200 bg-amber-100 px-4 py-2">
                <div class="flex items-center gap-1">
                  <span class="h-4 w-2 rounded-sm bg-amber-300"></span>
                  <span class="h-4 w-2 rounded-sm bg-rose-300"></span>
                  <span class="h-4 w-2 rounded-sm bg-indigo-300"></span>
                  <span class="h-4 w-2 rounded-sm bg-emerald-300"></span>
                </div>
                <span class="text-xs font-mono text-amber-900">Shelf: Read-only Livebook</span>
              </div>

              <div class="bg-white">
                <iframe
                  src="PASTE_READ_ONLY_EMBED_URL_HERE"
                  class="h-[600px] w-full"
                  loading="lazy"
                  referrerpolicy="no-referrer"
                ></iframe>
              </div>
            </div>

            <div class="mt-4 text-xs text-amber-700">
              If the embed doesn’t load, open Livebook in a new tab:
              <a
                href="http://localhost:8080"
                target="_blank"
                rel="noreferrer"
                class="font-semibold text-amber-800 hover:text-amber-900"
              >
                http://localhost:8080
              </a>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
