defmodule Core.PortfolioTest do
  use Core.DataCase

  alias Core.Portfolio

  describe "projects" do
    alias Core.Portfolio.Project

    import Core.PortfolioFixtures

    @invalid_attrs %{status: nil, description: nil, title: nil, slug: nil, image_url: nil, github_url: nil}

    test "list_projects/0 returns all projects" do
      project = project_fixture()
      assert Portfolio.list_projects() == [project]
    end

    test "get_project!/1 returns the project with given id" do
      project = project_fixture()
      assert Portfolio.get_project!(project.id) == project
    end

    test "create_project/1 with valid data creates a project" do
      valid_attrs = %{status: "some status", description: "some description", title: "some title", slug: "some slug", image_url: "some image_url", github_url: "some github_url"}

      assert {:ok, %Project{} = project} = Portfolio.create_project(valid_attrs)
      assert project.status == "some status"
      assert project.description == "some description"
      assert project.title == "some title"
      assert project.slug == "some slug"
      assert project.image_url == "some image_url"
      assert project.github_url == "some github_url"
    end

    test "create_project/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Portfolio.create_project(@invalid_attrs)
    end

    test "update_project/2 with valid data updates the project" do
      project = project_fixture()
      update_attrs = %{status: "some updated status", description: "some updated description", title: "some updated title", slug: "some updated slug", image_url: "some updated image_url", github_url: "some updated github_url"}

      assert {:ok, %Project{} = project} = Portfolio.update_project(project, update_attrs)
      assert project.status == "some updated status"
      assert project.description == "some updated description"
      assert project.title == "some updated title"
      assert project.slug == "some updated slug"
      assert project.image_url == "some updated image_url"
      assert project.github_url == "some updated github_url"
    end

    test "update_project/2 with invalid data returns error changeset" do
      project = project_fixture()
      assert {:error, %Ecto.Changeset{}} = Portfolio.update_project(project, @invalid_attrs)
      assert project == Portfolio.get_project!(project.id)
    end

    test "delete_project/1 deletes the project" do
      project = project_fixture()
      assert {:ok, %Project{}} = Portfolio.delete_project(project)
      assert_raise Ecto.NoResultsError, fn -> Portfolio.get_project!(project.id) end
    end

    test "change_project/1 returns a project changeset" do
      project = project_fixture()
      assert %Ecto.Changeset{} = Portfolio.change_project(project)
    end
  end
end
