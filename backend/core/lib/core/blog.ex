defmodule Core.Blog do
  @moduledoc """
  Posts (custom or imported from Hacker News), tags and moderated comments.

  Context: Not used by any page yet. Lists only return published posts and approved
  comments;
  creating a comment bumps the post's comment count.

  ## Example

      {:ok, post} = Blog.create_post(%{title: "Hello", content: "..."})
      {:ok, post} = Blog.publish_post(post)
  """

  import Ecto.Query, warn: false
  alias Core.Repo

  alias Core.Blog.{Post, Comment}

  @doc "Published posts, featured first, then newest."
  def list_published_posts do
    Post
    |> where([p], p.is_published == true)
    |> order_by([p], desc: p.featured, desc: p.published_at)
    |> preload(:user)
    |> Repo.all()
  end

  @doc "A page of published posts with paging info."
  def list_published_posts_paginated(page \\ 1, per_page \\ 10) do
    offset = (page - 1) * per_page

    posts =
      Post
      |> where([p], p.is_published == true)
      |> order_by([p], desc: p.featured, desc: p.published_at)
      |> limit(^per_page)
      |> offset(^offset)
      |> preload(:user)
      |> Repo.all()

    total_count =
      Post
      |> where([p], p.is_published == true)
      |> Repo.aggregate(:count)

    %{
      posts: posts,
      page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: ceil(total_count / per_page)
    }
  end

  @doc "Up to `limit` featured published posts."
  def list_featured_posts(limit \\ 5) do
    Post
    |> where([p], p.featured == true and p.is_published == true)
    |> order_by([p], desc: p.published_at)
    |> limit(^limit)
    |> preload(:user)
    |> Repo.all()
  end

  @doc "Published posts from a source (`hackernews` or `custom`)."
  def list_posts_by_source(source) do
    Post
    |> where([p], p.source == ^source and p.is_published == true)
    |> order_by([p], desc: p.published_at)
    |> preload(:user)
    |> Repo.all()
  end

  @doc "Published posts with this tag, newest first."
  def list_by_tag(tag) do
    Post
    |> where([p], p.tags == ^tag and p.is_published == true)
    |> order_by([p], desc: p.published_at)
    |> preload(:user)
    |> Repo.all()
  end

  @doc "A post by id; raises if missing."
  def get_post!(id) do
    Post
    |> preload([:user, comments: [:user, :replies]])
    |> Repo.get!(id)
  end

  @doc "The post with this slug, or nil."
  def get_post_by_slug(slug) do
    Post
    |> where([p], p.slug == ^slug)
    |> preload([:user, comments: [:user, :replies]])
    |> Repo.one()
  end

  @doc "The imported post with this external id (Hacker News), or nil."
  def get_post_by_external_id(external_id) do
    Repo.get_by(Post, external_id: external_id, source: "hackernews")
  end

  @doc "Creates a post."
  def create_post(attrs \\ %{}) do
    %Post{}
    |> Post.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Updates a post."
  def update_post(%Post{} = post, attrs) do
    post
    |> Post.changeset(attrs)
    |> Repo.update()
  end

  @doc "Deletes a post."
  def delete_post(%Post{} = post) do
    Repo.delete(post)
  end

  @doc "Publishes a post and stamps `published_at`."
  def publish_post(%Post{} = post) do
    post
    |> Ecto.Changeset.change(%{
      is_published: true,
      published_at: DateTime.utc_now()
    })
    |> Repo.update()
  end

  @doc "Unpublishes a post."
  def unpublish_post(%Post{} = post) do
    post
    |> Ecto.Changeset.change(%{is_published: false})
    |> Repo.update()
  end

  @doc "Adds one to a post's comment count."
  def increment_comment_count(%Post{} = post) do
    from(p in Post, where: p.id == ^post.id)
    |> Repo.update_all(inc: [comments_count: 1])
  end

  @doc "A post's approved comments."
  def list_post_comments(post_id) do
    Comment
    |> where([c], c.post_id == ^post_id and c.approved == true and is_nil(c.parent_id))
    |> order_by([c], desc: c.inserted_at)
    |> preload([:user, replies: [:user]])
    |> Repo.all()
  end

  @doc "A post's comments, including unapproved ones (moderation)."
  def list_all_comments(post_id) do
    Comment
    |> where([c], c.post_id == ^post_id)
    |> order_by([c], desc: c.inserted_at)
    |> preload(:user)
    |> Repo.all()
  end

  @doc "A comment by id; raises if missing."
  def get_comment!(id) do
    Comment
    |> preload([:user, :post])
    |> Repo.get!(id)
  end

  @doc "Creates a comment and bumps the post's comment count."
  def create_comment(attrs \\ %{}) do
    inserted_comment =
      %Comment{}
      |> Comment.changeset(attrs)
      |> Repo.insert()

    case inserted_comment do
      {:ok, comment} ->
        if post = Repo.get(Post, comment.post_id) do
          increment_comment_count(post)
        end

        {:ok, comment}

      error ->
        error
    end
  end

  @doc "Updates a comment."
  def update_comment(%Comment{} = comment, attrs) do
    comment
    |> Comment.changeset(attrs)
    |> Repo.update()
  end

  @doc "Deletes a comment."
  def delete_comment(%Comment{} = comment) do
    Repo.delete(comment)
  end

  @doc "Approves a comment so it's listed."
  def approve_comment(%Comment{} = comment) do
    comment
    |> Ecto.Changeset.change(%{approved: true})
    |> Repo.update()
  end

  @doc "Rejects a comment."
  def reject_comment(%Comment{} = comment) do
    comment
    |> Ecto.Changeset.change(%{approved: false})
    |> Repo.update()
  end

  @doc "A post changeset for forms."
  def change_post(%Post{} = post, attrs \\ %{}) do
    Post.changeset(post, attrs)
  end

  @doc "A comment changeset for forms."
  def change_comment(%Comment{} = comment, attrs \\ %{}) do
    Comment.changeset(comment, attrs)
  end
end
