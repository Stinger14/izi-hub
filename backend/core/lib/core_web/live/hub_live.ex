defmodule CoreWeb.HubLive do
  use CoreWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, count: 0)}
  end

  def handle_event("inc", _params, socket) do
    {:noreply, update(socket, :count, &(&1 + 1))}
  end

  def render(assigns) do
    ~H"""
    <main style="padding: 24px;">
    <h1>IziHub LiveView</h1>
    <p>Count: <%= @count %></p>

    <button phx-click="Increase">+1</button>
    </main>
    """
  end
end
