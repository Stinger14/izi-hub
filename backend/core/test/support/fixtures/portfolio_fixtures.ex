defmodule Core.PortfolioFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Core.Portfolio` context.
  """

  @doc """
  Generate a project.
  """
  def project_fixture(attrs \\ %{}) do
    {:ok, project} =
      attrs
      |> Enum.into(%{
        description: "some description",
        github_url: "some github_url",
        image_url: "some image_url",
        slug: "some slug",
        status: "some status",
        title: "some title"
      })
      |> Core.Portfolio.create_project()

    project
  end
end
