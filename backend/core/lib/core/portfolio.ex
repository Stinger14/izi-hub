defmodule IziHub.Portfolio do
  @moduledoc """
  Portfolio projects and the tech stacks they use.

  Context: Not used by any page yet. (the public Profile/CV page is static content).

  ## Example

      {:ok, project} = Portfolio.create_project(%{name: "IziHub", slug: "izihub"})
      Portfolio.add_tech_stacks_to_project(project, [elixir.id])
  """

  import Ecto.Query, warn: false
  alias Core.Repo
  alias Core.Portfolio.{Project, TechStack}

  ## Projects

  @doc "All projects."
  def list_projects do
    Project
    |> preload(:tech_stacks)
    |> order_by([p], desc: p.featured, asc: p.display_order, desc: p.inserted_at)
    |> Repo.all()
  end

  @doc "A user's projects."
  def list_user_projects(user_id) do
    Project
    |> where([p], p.user_id == ^user_id)
    |> preload(:tech_stacks)
    |> order_by([p], desc: p.featured, asc: p.display_order, desc: p.inserted_at)
    |> Repo.all()
  end

  @doc "Featured projects."
  def list_featured_projects do
    Project
    |> where([p], p.featured == true and p.status == "active")
    |> preload(:tech_stacks)
    |> order_by([p], asc: p.display_order, desc: p.inserted_at)
    |> Repo.all()
  end

  @doc "A project by id with its tech stacks; raises if missing."
  def get_project!(id) do
    Project
    |> preload(:tech_stacks)
    |> Repo.get!(id)
  end

  @doc "The project with this slug, or nil."
  def get_project_by_slug(slug) do
    Project
    |> where([p], p.slug == ^slug)
    |> preload(:tech_stacks)
    |> Repo.one()
  end

  @doc "Creates a project."
  def create_project(attrs \\ %{}) do
    %Project{}
    |> Project.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Updates a project."
  def update_project(%Project{} = project, attrs) do
    project
    |> Project.changeset(attrs)
    |> Repo.update()
  end

  @doc "Deletes a project."
  def delete_project(%Project{} = project) do
    Repo.delete(project)
  end

  @doc "Links tech stacks (by id) to a project."
  def add_tech_stacks_to_project(%Project{} = project, tech_stack_ids) do
    tech_stacks = Repo.all(from t in TechStack, where: t.id in ^tech_stack_ids)

    project
    |> Repo.preload(:tech_stacks)
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:tech_stacks, tech_stacks)
    |> Repo.update()
  end

  @doc "Unlinks tech stacks (by id) from a project."
  def remove_tech_stacks_from_project(%Project{} = project, tech_stack_ids) do
    project = Repo.preload(project, :tech_stacks)
    remaining_stacks = Enum.reject(project.tech_stacks, fn ts -> ts.id in tech_stack_ids end)

    project
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:tech_stacks, remaining_stacks)
    |> Repo.update()
  end

  ## Tech Stacks

  @doc "All tech stacks."
  def list_tech_stacks do
    TechStack
    |> order_by([t], asc: t.category, asc: t.name)
    |> Repo.all()
  end

  @doc "Tech stacks grouped by category."
  def list_tech_stacks_by_category do
    TechStack
    |> order_by([t], asc: t.category, asc: t.name)
    |> Repo.all()
    |> Enum.group_by(& &1.category)
  end

  @doc "A tech stack by id; raises if missing."
  def get_tech_stack!(id), do: Repo.get!(TechStack, id)

  @doc "The tech stack with this name, or nil."
  def get_tech_stack_by_name(name) do
    Repo.get_by(TechStack, name: name)
  end

  @doc "Creates a tech stack."
  def create_tech_stack(attrs \\ %{}) do
    %TechStack{}
    |> TechStack.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Updates a tech stack."
  def update_tech_stack(%TechStack{} = tech_stack, attrs) do
    tech_stack
    |> TechStack.changeset(attrs)
    |> Repo.update()
  end

  @doc "Deletes a tech stack."
  def delete_tech_stack(%TechStack{} = tech_stack) do
    Repo.delete(tech_stack)
  end

  @doc "A tech stack changeset for forms."
  def change_tech_stack(%TechStack{} = tech_stack, attrs \\ %{}) do
    TechStack.changeset(tech_stack, attrs)
  end
end
