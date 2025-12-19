defmodule IziHub.Portfolio do
  @moduledoc """
  The Portfolio context - manages projects and tech stacks
  """

  import Ecto.Query, warn: false
  alias Core.Repo
  alias Core.Portfolio.{Project, TechStack}

  ## Projects

  @doc """
  Returns the list of projects
  """
  def list_projects do
    Project
    |> preload(:tech_stacks)
    |> order_by([p], desc: p.featured, asc: p.display_order, desc: p.inserted_at)
    |> Repo.all()
  end

  @doc """
  Returns the list of projects for a specific user
  """
  def list_user_projects(user_id) do
    Project
    |> where([p], p.user_id == ^user_id)
    |> preload(:tech_stacks)
    |> order_by([p], desc: p.featured, asc: p.display_order, desc: p.inserted_at)
    |> Repo.all()
  end

  @doc """
  Returns featured projects
  """
  def list_featured_projects do
    Project
    |> where([p], p.featured == true and p.status == "active")
    |> preload(:tech_stacks)
    |> order_by([p], asc: p.display_order, desc: p.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single project
  """
  def get_project!(id) do
    Project
    |> preload(:tech_stacks)
    |> Repo.get!(id)
  end

  @doc """
  Gets a project by slug
  """
  def get_project_by_slug(slug) do
    Project
    |> where([p], p.slug == ^slug)
    |> preload(:tech_stacks)
    |> Repo.one()
  end

  @doc """
  Creates a project
  """
  def create_project(attrs \\ %{}) do
    %Project{}
    |> Project.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a project
  """
  def update_project(%Project{} = project, attrs) do
    project
    |> Project.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a project
  """
  def delete_project(%Project{} = project) do
    Repo.delete(project)
  end

  @doc """
  Associates tech stacks with a project
  """
  def add_tech_stacks_to_project(%Project{} = project, tech_stack_ids) do
    tech_stacks = Repo.all(from t in TechStack, where: t.id in ^tech_stack_ids)

    project
    |> Repo.preload(:tech_stacks)
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:tech_stacks, tech_stacks)
    |> Repo.update()
  end

  @doc """
  Removes tech stacks from a project
  """
  def remove_tech_stacks_from_project(%Project{} = project, tech_stack_ids) do
    project = Repo.preload(project, :tech_stacks)
    remaining_stacks = Enum.reject(project.tech_stacks, fn ts -> ts.id in tech_stack_ids end)

    project
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:tech_stacks, remaining_stacks)
    |> Repo.update()
  end

  ## Tech Stacks

  @doc """
  Returns the list of tech stacks
  """
  def list_tech_stacks do
    TechStack
    |> order_by([t], asc: t.category, asc: t.name)
    |> Repo.all()
  end

  @doc """
  Returns tech stacks grouped by category
  """
  def list_tech_stacks_by_category do
    TechStack
    |> order_by([t], asc: t.category, asc: t.name)
    |> Repo.all()
    |> Enum.group_by(& &1.category)
  end

  @doc """
  Gets a single tech stack
  """
  def get_tech_stack!(id), do: Repo.get!(TechStack, id)

  @doc """
  Gets a tech stack by name
  """
  def get_tech_stack_by_name(name) do
    Repo.get_by(TechStack, name: name)
  end

  @doc """
  Creates a tech stack
  """
  def create_tech_stack(attrs \\ %{}) do
    %TechStack{}
    |> TechStack.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a tech stack
  """
  def update_tech_stack(%TechStack{} = tech_stack, attrs) do
    tech_stack
    |> TechStack.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a tech stack
  """
  def delete_tech_stack(%TechStack{} = tech_stack) do
    Repo.delete(tech_stack)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking tech stack changes
  """
  def change_tech_stack(%TechStack{} = tech_stack, attrs \\ %{}) do
    TechStack.changeset(tech_stack, attrs)
  end
end
