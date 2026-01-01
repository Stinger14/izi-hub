defmodule Core.AnalyticsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Core.Analytics` context.
  """

  @doc """
  Generate a page_view.
  """
  def page_view_fixture(attrs \\ %{}) do
    {:ok, page_view} =
      attrs
      |> Enum.into(%{
        city: "some city",
        country: "some country",
        devive_type: "some devive_type",
        page_path: "some page_path",
        referrer: "some referrer",
        user_agent: "some user_agent"
      })
      |> Core.Analytics.create_page_view()

    page_view
  end
end
