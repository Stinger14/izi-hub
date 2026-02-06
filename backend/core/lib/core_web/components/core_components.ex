defmodule CoreWeb.CoreComponents do
  use Phoenix.Component

  @doc "Renders an icon by name"
  attr :name, :string, required: true
  attr :class, :string, default: nil

  def icon(assigns) do
    ~H"""
    <%= case @name do %>
      <% "hero-check" -> %>
        <svg
          xmlns="http://www.w3.org/2000/svg"
          fill="none"
          viewBox="0 0 24 24"
          stroke-width="2"
          stroke="currentColor"
          class={@class}
        >
          <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
        </svg>
      <% "hero-x-mark" -> %>
        <svg
          xmlns="http://www.w3.org/2000/svg"
          fill="none"
          viewBox="0 0 24 24"
          stroke-width="2"
          stroke="currentColor"
          class={@class}
        >
          <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
        </svg>
      <% _ -> %>
        <span class={@class}></span>
    <% end %>
    """
  end
end
