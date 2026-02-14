defmodule CoreWeb.ErrorHTML do
  @moduledoc """
  Renders error pages for HTML requests.
  """

  use CoreWeb, :html

  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
