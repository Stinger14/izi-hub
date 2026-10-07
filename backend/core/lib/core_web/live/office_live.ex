defmodule CoreWeb.OfficeLive do
  use CoreWeb, :live_view

  alias Core.Office
  alias Core.Office.TimelineLayout
  alias Phoenix.LiveView.JS

  @calendar_weekdays ~w(Sun Mon Tue Wed Thu Fri Sat)
  @default_entry_kind "task"
  @roadmap_start_hour 8
  @roadmap_end_hour 22
  @roadmap_default_task_hour 9
  @milestone_kinds [
    {"Milestone", "milestone"},
    {"Deadline", "deadline"},
    {"Release", "release"},
    {"Note", "note"}
  ]

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign_new(:current_scope, fn -> nil end)
     |> assign(
       calendar_month: month_start(Date.utc_today()),
       current_project: nil,
       current_project_summary: nil,
       default_project_id: nil,
       editing_timeline_entry_id: nil,
       projects: [],
       project_delete_confirm: false,
       project_form_open: false,
       entry_form_open: false,
       entry_kind: @default_entry_kind,
       expanded_item_ids: [],
       page_title: "IziOffice",
       selected_date: nil,
       selected_day_entry_form_open: false,
       selected_day_expanded_task_ids: [],
       timeline_edit_form: nil
     )
     |> assign_project_form()
     |> assign_entry_form()
     |> assign_selected_day_entry_form()}
  end

  def handle_params(params, _uri, socket) do
    user = socket.assigns.current_scope.user
    default_project = Office.default_project_for_user(user)
    current_project = Office.get_project_for_user(user, params["slug"])
    projects = Office.list_projects_for_user(user)

    {:noreply,
     socket
     |> assign(
       default_project_id: default_project.id,
       project_delete_confirm: false,
       projects: projects,
       current_project: current_project
     )
     |> assign_workbench()}
  end

  def handle_event("open_entry_form", _params, socket) do
    {:noreply,
     assign(socket,
       entry_form_open: true,
       project_form_open: false,
       project_delete_confirm: false
     )}
  end

  def handle_event("close_entry_form", _params, socket) do
    {:noreply,
     socket
     |> assign(
       editing_timeline_entry_id: nil,
       entry_form_open: false,
       entry_kind: @default_entry_kind
     )
     |> assign_entry_form()}
  end

  def handle_event("select_entry_kind", %{"kind" => kind}, socket) do
    kind = normalize_entry_kind(kind)

    {:noreply,
     socket
     |> assign(entry_kind: kind, entry_form_open: true)
     |> assign_entry_form(kind)}
  end

  def handle_event("create_entry", %{"entry" => params}, socket) do
    user = socket.assigns.current_scope.user
    project = socket.assigns.current_project

    case socket.assigns.entry_kind do
      "milestone" -> create_milestone(socket, user, project, params)
      _ -> create_task(socket, user, project, params)
    end
  end

  def handle_event("open_project_form", _params, socket) do
    {:noreply,
     assign(socket,
       project_form_open: true,
       entry_form_open: false,
       project_delete_confirm: false
     )}
  end

  def handle_event("close_project_form", _params, socket) do
    {:noreply, socket |> assign(project_form_open: false) |> assign_project_form()}
  end

  def handle_event("create_project", %{"project" => params}, socket) do
    user = socket.assigns.current_scope.user

    case Office.create_project(user, params) do
      {:ok, project} ->
        {:noreply,
         socket
         |> put_flash(:info, "Project created")
         |> assign(project_form_open: false)
         |> assign_project_form()
         |> push_patch(to: ~p"/office/#{project.slug}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(project_form_open: true)
         |> assign(project_form: to_form(changeset, as: :project))}
    end
  end

  def handle_event("open_delete_project_confirm", _params, socket) do
    {:noreply, assign(socket, project_delete_confirm: true, project_form_open: false)}
  end

  def handle_event("cancel_delete_project_confirm", _params, socket) do
    {:noreply, assign(socket, project_delete_confirm: false)}
  end

  def handle_event("archive_current_project", _params, socket) do
    user = socket.assigns.current_scope.user
    project = socket.assigns.current_project
    default_project = Office.default_project_for_user(user)

    case Office.archive_project(user, project) do
      {:ok, _archived_project} ->
        {:noreply,
         socket
         |> put_flash(:info, "Project archived")
         |> assign(project_delete_confirm: false)
         |> push_patch(to: ~p"/office/#{default_project.slug}")}

      {:error, :protected_default} ->
        {:noreply, put_flash(socket, :error, "The default project cannot be archived")}

      {:error, :forbidden} ->
        {:noreply, put_flash(socket, :error, "You do not have access to that project")}

      {:error, %Ecto.Changeset{}} ->
        {:noreply, put_flash(socket, :error, "Unable to archive project right now")}
    end
  end

  def handle_event("delete_current_project", _params, socket) do
    user = socket.assigns.current_scope.user
    project = socket.assigns.current_project
    default_project = Office.default_project_for_user(user)

    case Office.delete_project(user, project) do
      {:ok, _deleted_project} ->
        {:noreply,
         socket
         |> put_flash(:info, "Project deleted")
         |> assign(project_delete_confirm: false)
         |> push_patch(to: ~p"/office/#{default_project.slug}")}

      {:error, :protected_default} ->
        {:noreply, put_flash(socket, :error, "The default project cannot be deleted")}

      {:error, :forbidden} ->
        {:noreply, put_flash(socket, :error, "You do not have access to that project")}

      {:error, %Ecto.Changeset{}} ->
        {:noreply, put_flash(socket, :error, "Unable to delete project right now")}
    end
  end

  def handle_event("toggle_canvas_item", %{"id" => id}, socket) do
    {:noreply,
     assign(socket, expanded_item_ids: toggle_item(socket.assigns.expanded_item_ids, id))}
  end

  def handle_event("close_roadmap_items", _params, socket) do
    roadmap_item_ids = MapSet.new(socket.assigns.roadmap_item_ids || [])

    {:noreply,
     assign(socket,
       expanded_item_ids:
         Enum.reject(socket.assigns.expanded_item_ids, &MapSet.member?(roadmap_item_ids, &1))
     )}
  end

  def handle_event("close_stage_items", _params, socket) do
    stage_item_ids = MapSet.new(stage_item_ids(socket.assigns.canvas_stage_items))

    {:noreply,
     assign(socket,
       expanded_item_ids:
         Enum.reject(socket.assigns.expanded_item_ids, &MapSet.member?(stage_item_ids, &1))
     )}
  end

  def handle_event("transition_work_item", %{"id" => work_item_id, "to" => to_status}, socket) do
    user = socket.assigns.current_scope.user
    project = socket.assigns.current_project
    work_item = Office.get_work_item_for_project!(user.id, project.id, work_item_id)

    case Office.transition_work_item(work_item, to_status, user) do
      {:ok, updated_work_item} ->
        {:noreply,
         socket
         |> assign_workbench()
         |> assign(
           expanded_item_ids:
             Enum.uniq(["work-item:" <> updated_work_item.id | socket.assigns.expanded_item_ids])
         )
         |> put_flash(:info, lane_message(to_status))}

      {:error, :invalid_transition} ->
        {:noreply, put_flash(socket, :error, "That status change is not allowed")}

      {:error, %Ecto.Changeset{}} ->
        {:noreply, put_flash(socket, :error, "Unable to move task right now")}
    end
  end

  def handle_event("edit_timeline_entry", %{"id" => id}, socket) do
    user = socket.assigns.current_scope.user
    project = socket.assigns.current_project
    timeline_entry = Office.get_timeline_entry_for_project!(user.id, project.id, id)

    {:noreply,
     socket
     |> assign(
       editing_timeline_entry_id: timeline_entry.id,
       expanded_item_ids:
         Enum.uniq(["timeline-entry:" <> timeline_entry.id | socket.assigns.expanded_item_ids]),
       timeline_edit_form:
         to_form(
           Office.timeline_entry_changeset(timeline_entry, timeline_entry_attrs(timeline_entry)),
           as: :entry
         )
     )
     |> maybe_focus_date(NaiveDateTime.to_date(timeline_entry.starts_at))}
  end

  def handle_event("cancel_timeline_edit", _params, socket) do
    {:noreply, assign(socket, editing_timeline_entry_id: nil, timeline_edit_form: nil)}
  end

  def handle_event("save_timeline_entry", %{"entry" => params}, socket) do
    user = socket.assigns.current_scope.user
    project = socket.assigns.current_project

    timeline_entry =
      Office.get_timeline_entry_for_project!(
        user.id,
        project.id,
        socket.assigns.editing_timeline_entry_id
      )

    case Office.update_timeline_entry(timeline_entry, params) do
      {:ok, updated_entry} ->
        {:noreply,
         socket
         |> assign(editing_timeline_entry_id: nil, timeline_edit_form: nil)
         |> assign(selected_date: NaiveDateTime.to_date(updated_entry.starts_at))
         |> assign_workbench()
         |> assign(expanded_item_ids: ["timeline-entry:" <> updated_entry.id])
         |> put_flash(:info, "Milestone updated")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, timeline_edit_form: to_form(changeset, as: :entry))}
    end
  end

  def handle_event("select_calendar_date", %{"date" => value}, socket) do
    case Date.from_iso8601(value) do
      {:ok, date} ->
        {:noreply,
         socket
         |> assign(
           selected_date: date,
           calendar_month: month_start(date),
           selected_day_entry_form_open: false
         )
         |> assign_workbench()
         |> assign_selected_day_entry_form(selected_date_task_attrs(date))}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  def handle_event("clear_calendar_date", _params, socket) do
    {:noreply,
     socket
     |> assign(selected_date: nil, selected_day_entry_form_open: false)
     |> assign_workbench()
     |> assign_selected_day_entry_form()}
  end

  def handle_event("toggle_selected_day_entry_form", _params, socket) do
    if socket.assigns.selected_date do
      if socket.assigns.selected_day_entry_form_open do
        {:noreply,
         socket
         |> assign(selected_day_entry_form_open: false)
         |> assign_selected_day_entry_form()}
      else
        {:noreply,
         socket
         |> assign(
           entry_form_open: false,
           project_form_open: false,
           project_delete_confirm: false,
           selected_day_entry_form_open: true
         )
         |> assign_selected_day_entry_form(selected_date_task_attrs(socket.assigns.selected_date))}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("cancel_selected_day_entry_form", _params, socket) do
    {:noreply,
     socket
     |> assign(selected_day_entry_form_open: false)
     |> assign_selected_day_entry_form()}
  end

  def handle_event("create_selected_day_task", %{"selected_day_entry" => params}, socket) do
    user = socket.assigns.current_scope.user
    project = socket.assigns.current_project

    case socket.assigns.selected_date do
      %Date{} = selected_date ->
        params = Map.put(params, "scheduled_for", Date.to_iso8601(selected_date))

        case Office.create_work_item(user, project, params) do
          {:ok, work_item} ->
            {:noreply,
             socket
             |> put_flash(:info, "Task added to roadmap")
             |> assign(
               selected_day_entry_form_open: false,
               expanded_item_ids: ["work-item:" <> work_item.id]
             )
             |> assign_selected_day_entry_form(selected_date_task_attrs(selected_date))
             |> assign_workbench()}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply,
             socket
             |> assign(
               entry_form_open: false,
               selected_day_entry_form_open: true,
               selected_day_entry_form: to_form(changeset, as: :selected_day_entry)
             )}
        end

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("focus_day_task", %{"id" => id}, socket) do
    {:noreply,
     assign(socket,
       expanded_item_ids: Enum.uniq([id | socket.assigns.expanded_item_ids])
     )}
  end

  def handle_event("toggle_day_task_details", %{"id" => id}, socket) do
    {:noreply,
     assign(socket,
       selected_day_expanded_task_ids:
         toggle_item(socket.assigns.selected_day_expanded_task_ids, id)
     )}
  end

  def handle_event("prev_calendar_month", _params, socket) do
    {:noreply,
     socket
     |> assign(
       calendar_month: previous_month(socket.assigns.calendar_month),
       selected_date: nil,
       selected_day_entry_form_open: false
     )
     |> assign_workbench()
     |> assign_selected_day_entry_form()}
  end

  def handle_event("next_calendar_month", _params, socket) do
    {:noreply,
     socket
     |> assign(
       calendar_month: next_month(socket.assigns.calendar_month),
       selected_date: nil,
       selected_day_entry_form_open: false
     )
     |> assign_workbench()
     |> assign_selected_day_entry_form()}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} theme="hub">
      <div class="min-h-screen">
        <main class="mx-auto max-w-7xl px-6 pb-16 pt-12">
          <section class="mb-8 flex flex-wrap items-end justify-between gap-4">
            <div>
              <p class="text-xs font-semibold uppercase tracking-[0.24em] text-[var(--hub-secondary)]">Private roadmap canvas</p>
              <h1 class="mt-3 text-4xl font-semibold tracking-tight text-[var(--hub-text)] sm:text-5xl">
                IziOffice
              </h1>
            </div>

            <div :if={@current_project} class="hub-glass rounded-2xl px-4 py-3">
              <div class="flex items-start justify-between gap-4">
                <div>
                  <p class="text-[11px] font-semibold uppercase tracking-wide text-[var(--hub-muted)]">Current project</p>
                  <div class="mt-1 flex items-center gap-2">
                    <p class="text-sm font-semibold text-[var(--hub-text)]"><%= @current_project.name %></p>
                    <span
                      :if={current_project_default?(@current_project, @default_project_id)}
                      class="rounded-full border border-[color:var(--hub-border)] bg-[color:var(--hub-accent)]/12 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-[var(--hub-secondary)]"
                    >
                      Default
                    </span>
                  </div>
                  <p class="mt-1 text-xs text-[var(--hub-muted)]">
                    <%= length(@canvas_milestones) %> milestones and <%= @canvas_item_count %> roadmap cards
                  </p>
                </div>

                <div
                  :if={!current_project_default?(@current_project, @default_project_id)}
                  class="flex flex-wrap items-center justify-end gap-2"
                >
                  <button type="button" phx-click="archive_current_project" class="btn btn-secondary btn-xs">
                    Archive
                  </button>
                  <button type="button" phx-click="open_delete_project_confirm" class="btn btn-ghost btn-xs text-[var(--tone-expense)] hover:text-[var(--tone-expense)]">
                    Delete
                  </button>
                </div>
              </div>

              <div
                :if={@project_delete_confirm && !current_project_default?(@current_project, @default_project_id)}
                class="mt-4 rounded-2xl border border-[color:var(--tone-expense)]/35 bg-[color:var(--tone-expense)]/12 p-4"
              >
                <p class="text-[11px] font-semibold uppercase tracking-[0.18em] text-[var(--tone-expense)]">Delete project</p>
                <p class="mt-2 text-sm font-semibold text-[var(--hub-text)]">
                  Delete "<%= @current_project.name %>" permanently?
                </p>
                <p class="mt-1 text-sm text-[var(--hub-muted)]">
                  This removes <%= @current_project_summary.work_item_count %> tasks,
                  <%= @current_project_summary.timeline_entry_count %> milestones, and
                  <%= @current_project_summary.transition_count %> transition records.
                </p>

                <div class="mt-4 flex flex-wrap items-center justify-end gap-2">
                  <button type="button" phx-click="cancel_delete_project_confirm" class="btn btn-ghost btn-xs">
                    Cancel
                  </button>
                  <button type="button" phx-click="delete_current_project" class="btn btn-danger btn-xs">
                    Delete project
                  </button>
                </div>
              </div>
            </div>
          </section>

          <section class="overflow-hidden rounded-[2rem] border border-[color:var(--hub-border)] bg-[var(--hub-surface)] shadow-[0_30px_80px_-45px_rgba(109,40,217,0.45)] backdrop-blur">
            <div class="border-b border-[color:var(--hub-border)] bg-gradient-to-r from-[color:var(--hub-accent)]/12 via-[color:var(--hub-accent)]/5 to-transparent px-6 py-6">
              <div class="flex flex-col gap-5 xl:flex-row xl:items-end xl:justify-between">
                <div class="flex-1">
                  <p class="text-xs font-semibold uppercase tracking-wide text-[var(--hub-muted)]">Projects</p>
                  <div class="mt-3 flex flex-wrap gap-2">
                    <a
                      :for={project <- @projects}
                      href={office_project_path(project)}
                      class={project_link_class(project, @current_project)}
                    >
                      <span class="truncate"><%= project.name %></span>
                    </a>
                  </div>
                </div>

                <div class="flex flex-wrap items-start gap-3">
                  <div class={project_action_shell_class(@project_form_open)}>
                    <button
                      :if={!@project_form_open}
                      type="button"
                      phx-click="open_project_form"
                      class="hub-glass group inline-flex w-full items-center gap-2 rounded-2xl px-4 py-3 text-sm font-semibold text-[var(--hub-text)] transition-all duration-300 ease-out hover:-translate-y-0.5 hover:scale-[1.01] hover:border-[color:var(--hub-accent)]/50 hover: active:translate-y-0 active:scale-[0.99]"
                    >
                      <span class="inline-flex h-7 w-7 items-center justify-center rounded-full bg-[var(--hub-surface)] text-base leading-none text-[var(--hub-muted)] transition-transform duration-300 ease-out group-hover:rotate-90">
                        +
                      </span>
                      New project
                    </button>

                    <.form
                      :if={@project_form_open}
                      for={@project_form}
                      phx-submit="create_project"
                      class="w-full rounded-2xl border border-[color:var(--hub-border)] bg-[var(--hub-surface)] p-2.5 shadow-[0_18px_36px_-28px_rgba(109,40,217,0.45)] transition-all duration-300 ease-out"
                    >
                      <div class="flex flex-col gap-2 sm:flex-row sm:items-center">
                        <div class="min-w-0 flex-1">
                          <input
                            id="project-name"
                            name={@project_form[:name].name}
                            value={@project_form[:name].value}
                            type="text"
                            placeholder="Project title"
                            class="w-full rounded-xl border border-[color:var(--hub-border)] bg-[var(--hub-surface)] px-4 py-3 text-sm text-[var(--hub-text)] outline-none transition-all duration-200 focus:border-[color:var(--hub-accent)]/50 focus:ring-2 focus:ring-[color:var(--hub-accent)]/30"
                          />
                          <p :for={error <- @project_form[:name].errors} class="mt-1 text-xs text-[var(--tone-expense)]">
                            <%= translate_error(error) %>
                          </p>
                        </div>

                        <div class="flex items-center justify-end gap-2">
                          <button type="button" phx-click="close_project_form" class="btn btn-ghost btn-xs">
                            Cancel
                          </button>
                          <button type="submit" class="btn btn-primary btn-xs">Create</button>
                        </div>
                      </div>
                    </.form>
                  </div>
                </div>
              </div>

              <div :if={@entry_form_open} class="mt-5 flex justify-end">
                <.form
                  for={@entry_form}
                  phx-submit="create_entry"
                  class="w-full max-w-xl rounded-[1.5rem] border border-[color:var(--hub-border)] bg-[var(--hub-surface)] p-4 shadow-[0_24px_60px_-38px_rgba(109,40,217,0.48)] backdrop-blur-sm transition-all duration-300 ease-out"
                >
                  <div class="flex items-center justify-between gap-4">
                    <div>
                      <p class="text-xs font-semibold uppercase tracking-wide text-[var(--hub-muted)]">Add roadmap entry</p>
                    </div>
                    <button
                      type="button"
                      phx-click="close_entry_form"
                      class="inline-flex h-9 w-9 items-center justify-center rounded-full border border-[color:var(--hub-border)] bg-[var(--hub-surface)] text-[var(--hub-muted)] transition hover:border-[color:var(--hub-border)] hover:text-[var(--hub-text)]"
                      aria-label="Close entry form"
                    >
                      <.icon name="hero-x-mark" class="h-4 w-4" />
                    </button>
                  </div>

                  <div class="mt-3 flex flex-wrap gap-2">
                    <button
                      type="button"
                      phx-click="select_entry_kind"
                      phx-value-kind="task"
                      class={entry_kind_class("task", @entry_kind)}
                    >
                      Task
                    </button>
                    <button
                      type="button"
                      phx-click="select_entry_kind"
                      phx-value-kind="milestone"
                      class={entry_kind_class("milestone", @entry_kind)}
                    >
                      Milestone
                    </button>
                  </div>

                  <div class="mt-4 space-y-3">
                    <div>
                      <label for="entry-title" class="mb-1 block text-[11px] font-semibold uppercase tracking-wide text-[var(--hub-muted)]">
                        Title
                      </label>
                      <input
                        id="entry-title"
                        name={@entry_form[:title].name}
                        value={@entry_form[:title].value}
                        type="text"
                        placeholder={entry_title_placeholder(@entry_kind)}
                        class="w-full rounded-xl border border-[color:var(--hub-border)] bg-[var(--hub-surface)] px-4 py-3 text-sm text-[var(--hub-text)] outline-none transition focus:border-[color:var(--hub-accent)]/50 focus:ring-2 focus:ring-[color:var(--hub-accent)]/30"
                      />
                      <p :for={error <- @entry_form[:title].errors} class="mt-1 text-xs text-[var(--tone-expense)]">
                        <%= translate_error(error) %>
                      </p>
                    </div>

                    <div>
                      <label for="entry-description" class="mb-1 block text-[11px] font-semibold uppercase tracking-wide text-[var(--hub-muted)]">
                        Description
                      </label>
                      <textarea
                        id="entry-description"
                        name={@entry_form[:description].name}
                        class="h-20 w-full rounded-xl border border-[color:var(--hub-border)] bg-[var(--hub-surface)] px-4 py-3 text-sm text-[var(--hub-text)] outline-none transition focus:border-[color:var(--hub-accent)]/50 focus:ring-2 focus:ring-[color:var(--hub-accent)]/30"
                        placeholder={entry_description_placeholder(@entry_kind)}
                      ><%= @entry_form[:description].value %></textarea>
                    </div>

                    <div :if={@entry_kind == "task"} class="grid gap-3 sm:grid-cols-3">
                      <div>
                        <label for="entry-priority" class="mb-1 block text-[11px] font-semibold uppercase tracking-wide text-[var(--hub-muted)]">
                          Priority
                        </label>
                        <select
                          id="entry-priority"
                          name={@entry_form[:priority].name}
                          class="w-full rounded-xl border border-[color:var(--hub-border)] bg-[var(--hub-surface)] px-4 py-3 text-sm text-[var(--hub-text)] outline-none transition focus:border-[color:var(--hub-accent)]/50 focus:ring-2 focus:ring-[color:var(--hub-accent)]/30"
                        >
                          <option value="low" selected={@entry_form[:priority].value == "low"}>Low</option>
                          <option value="medium" selected={@entry_form[:priority].value in [nil, "medium"]}>Medium</option>
                          <option value="high" selected={@entry_form[:priority].value == "high"}>High</option>
                        </select>
                      </div>

                      <div>
                        <label for="entry-scheduled-for" class="mb-1 block text-[11px] font-semibold uppercase tracking-wide text-[var(--hub-muted)]">
                          Scheduled
                        </label>
                        <input
                          id="entry-scheduled-for"
                          name={@entry_form[:scheduled_for].name}
                          value={@entry_form[:scheduled_for].value}
                          type="date"
                          class="w-full rounded-xl border border-[color:var(--hub-border)] bg-[var(--hub-surface)] px-4 py-3 text-sm text-[var(--hub-text)] outline-none transition focus:border-[color:var(--hub-accent)]/50 focus:ring-2 focus:ring-[color:var(--hub-accent)]/30"
                        />
                      </div>

                      <div>
                        <label for="entry-due-at" class="mb-1 block text-[11px] font-semibold uppercase tracking-wide text-[var(--hub-muted)]">
                          Due at
                        </label>
                        <input
                          id="entry-due-at"
                          name={@entry_form[:due_at].name}
                          value={datetime_local_value(@entry_form[:due_at].value)}
                          type="datetime-local"
                          class="w-full rounded-xl border border-[color:var(--hub-border)] bg-[var(--hub-surface)] px-4 py-3 text-sm text-[var(--hub-text)] outline-none transition focus:border-[color:var(--hub-accent)]/50 focus:ring-2 focus:ring-[color:var(--hub-accent)]/30"
                        />
                        <p :for={error <- @entry_form[:due_at].errors} class="mt-1 text-xs text-[var(--tone-expense)]">
                          <%= translate_error(error) %>
                        </p>
                      </div>
                    </div>

                    <div :if={@entry_kind == "milestone"} class="grid gap-3 sm:grid-cols-3">
                      <div>
                        <label for="entry-kind" class="mb-1 block text-[11px] font-semibold uppercase tracking-wide text-[var(--hub-muted)]">
                          Kind
                        </label>
                        <select
                          id="entry-kind"
                          name={@entry_form[:kind].name}
                          class="w-full rounded-xl border border-[color:var(--hub-border)] bg-[var(--hub-surface)] px-4 py-3 text-sm text-[var(--hub-text)] outline-none transition focus:border-[color:var(--hub-accent)]/50 focus:ring-2 focus:ring-[color:var(--hub-accent)]/30"
                        >
                          <option :for={{label, value} <- @milestone_kinds} value={value} selected={milestone_kind_selected?(@entry_form[:kind].value, value)}>
                            <%= label %>
                          </option>
                        </select>
                      </div>

                      <div>
                        <label for="entry-starts-at" class="mb-1 block text-[11px] font-semibold uppercase tracking-wide text-[var(--hub-muted)]">
                          Starts at
                        </label>
                        <input
                          id="entry-starts-at"
                          name={@entry_form[:starts_at].name}
                          value={datetime_local_value(@entry_form[:starts_at].value)}
                          type="datetime-local"
                          class="w-full rounded-xl border border-[color:var(--hub-border)] bg-[var(--hub-surface)] px-4 py-3 text-sm text-[var(--hub-text)] outline-none transition focus:border-[color:var(--hub-accent)]/50 focus:ring-2 focus:ring-[color:var(--hub-accent)]/30"
                        />
                        <p :for={error <- @entry_form[:starts_at].errors} class="mt-1 text-xs text-[var(--tone-expense)]">
                          <%= translate_error(error) %>
                        </p>
                      </div>

                      <div>
                        <label for="entry-ends-at" class="mb-1 block text-[11px] font-semibold uppercase tracking-wide text-[var(--hub-muted)]">
                          Ends at
                        </label>
                        <input
                          id="entry-ends-at"
                          name={@entry_form[:ends_at].name}
                          value={datetime_local_value(@entry_form[:ends_at].value)}
                          type="datetime-local"
                          class="w-full rounded-xl border border-[color:var(--hub-border)] bg-[var(--hub-surface)] px-4 py-3 text-sm text-[var(--hub-text)] outline-none transition focus:border-[color:var(--hub-accent)]/50 focus:ring-2 focus:ring-[color:var(--hub-accent)]/30"
                        />
                      </div>
                    </div>
                  </div>

                  <div class="mt-4 flex flex-wrap items-center justify-end gap-3">
                    <button type="button" phx-click="close_entry_form" class="btn btn-ghost btn-xs">
                      Cancel
                    </button>
                    <button type="submit" class="btn btn-primary btn-glow"><%= entry_submit_label(@entry_kind) %></button>
                  </div>
                </.form>
              </div>
            </div>

            <div class="px-6 py-6">
              <div class="grid gap-6 xl:grid-cols-[minmax(0,1fr)_20rem] xl:items-start">
                <div>
                  <div class="relative rounded-[1.75rem] border border-[color:var(--hub-border)] bg-[linear-gradient(180deg,rgba(36,30,56,0.97),rgba(23,22,28,0.97))] p-5 shadow-sm">
                    <div class="flex flex-wrap items-end justify-between gap-4">
                      <div>
                        <p class="text-xs font-semibold uppercase tracking-wide text-[var(--hub-secondary)]">Interactive Roadmap</p>
                      </div>

                      <button
                        :if={!@entry_form_open}
                        type="button"
                        phx-click="open_entry_form"
                        class="hub-glass group inline-flex items-center gap-2 rounded-2xl px-4 py-3 text-sm font-semibold text-[var(--hub-accent-2)] transition-all duration-300 ease-out hover:-translate-y-0.5 hover:scale-[1.01] hover:border-[color:var(--hub-accent)]/50 hover: active:translate-y-0 active:scale-[0.99]"
                      >
                        <span class="inline-flex h-7 w-7 items-center justify-center rounded-full bg-[color:var(--hub-accent)]/12 text-base leading-none text-[var(--hub-secondary)] transition-transform duration-300 ease-out group-hover:rotate-90">
                          +
                        </span>
                        Add entry
                      </button>
                    </div>

                    <div
                      class={
                        roadmap_canvas_class(
                          @roadmap_rows,
                          @expanded_item_ids,
                          @editing_timeline_entry_id
                        )
                      }
                    >
                      <%= if @roadmap_rows == [] do %>
                        <div class="flex min-h-[10rem] items-center justify-center rounded-xl border border-dashed border-[color:var(--hub-accent)]/20 bg-[color:var(--hub-accent)]/5 px-6 text-center text-sm text-[var(--hub-muted)]">
                          <%= empty_roadmap_message(@selected_date) %>
                        </div>
                      <% else %>
                        <div class="border-b border-[color:var(--hub-border)] bg-gradient-to-r from-[color:var(--hub-accent)]/12 via-[color:var(--hub-accent)]/5 to-transparent px-4 py-4">
                          <div class="grid grid-cols-[4.75rem_minmax(0,1fr)] items-end gap-3">
                            <div>
                              <p class="text-[10px] font-semibold uppercase tracking-[0.2em] text-[var(--hub-muted)]">Day</p>
                            </div>
                            <div class="relative h-12 rounded-2xl border border-[color:var(--hub-border)] bg-[var(--hub-surface)] shadow-[inset_0_1px_0_rgba(255,255,255,0.08)]">
                              <div
                                :for={tick <- @roadmap_hour_ticks}
                                class="absolute inset-y-0 flex -translate-x-1/2 items-center"
                                style={"left: #{tick.position_percent}%;"}
                              >
                                <span class="rounded-full border border-[color:var(--hub-border)] bg-[var(--hub-surface)] px-2 py-1 text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--hub-muted)] shadow-sm">
                                  <%= tick.label %>
                                </span>
                              </div>
                            </div>
                          </div>
                        </div>

                        <div class="relative">
                          <div
                            :if={
                              roadmap_canvas_focused?(
                                @roadmap_rows,
                                @expanded_item_ids,
                                @editing_timeline_entry_id
                              )
                            }
                            class={
                              roadmap_backdrop_class(
                                @roadmap_rows,
                                @expanded_item_ids,
                                @editing_timeline_entry_id
                              )
                            }
                          >
                          </div>

                          <div class="divide-y divide-[color:var(--hub-border)]/80">
                          <section
                            :for={row <- @roadmap_rows}
                            class="grid grid-cols-[4.75rem_minmax(0,1fr)] gap-3 px-4 py-4"
                            data-roadmap-date={Date.to_iso8601(row.date)}
                          >
                            <div class="pt-1">
                              <p class="text-[10px] font-semibold uppercase tracking-[0.2em] text-[var(--hub-muted)]">
                                <%= row.weekday_label %>
                              </p>
                              <p class="mt-1 text-sm font-semibold text-[var(--hub-text)]"><%= row.date_label %></p>
                            </div>

                            <div
                              class={
                                roadmap_row_class(
                                  row,
                                  @expanded_item_ids,
                                  @editing_timeline_entry_id,
                                  roadmap_focus_mode(
                                    @roadmap_rows,
                                    @expanded_item_ids,
                                    @editing_timeline_entry_id
                                  )
                                )
                              }
                              style={roadmap_row_style(row, @expanded_item_ids, @editing_timeline_entry_id)}
                            >
                              <%= for tick <- @roadmap_hour_ticks do %>
                                <div
                                  class="absolute bottom-0 top-0 w-px bg-[color:var(--hub-accent)]/12"
                                  style={"left: #{tick.position_percent}%;"}
                                >
                                </div>
                              <% end %>

                              <div
                                :for={item <- row.items}
                                class="absolute inset-x-0"
                                style={
                                  roadmap_item_lane_style(
                                    item,
                                    expanded?(@expanded_item_ids, item.id),
                                    @editing_timeline_entry_id == item.record_id
                                  )
                                }
                              >
                                <div
                                  :if={roadmap_duration_visible?(item)}
                                  class={roadmap_duration_class(item)}
                                  style={roadmap_duration_style(item)}
                                >
                                </div>

                                <div class="fx-item group/roadmap absolute z-10" style={roadmap_preview_anchor_style(item)}>
                                  <button
                                    type="button"
                                    phx-click="toggle_canvas_item"
                                    phx-value-id={item.id}
                                    data-roadmap-item-id={item.id}
                                    class={
                                      roadmap_dot_class(
                                        item,
                                        expanded?(@expanded_item_ids, item.id),
                                        @editing_timeline_entry_id == item.record_id
                                      )
                                    }
                                    aria-label={"Toggle #{item.title}"}
                                  >
                                  </button>

                                  <div
                                    :if={!expanded?(@expanded_item_ids, item.id)}
                                    class={roadmap_preview_class()}
                                    style={roadmap_preview_style(item)}
                                  >
                                    <div class="fx-preview-content">
                                      <div class="flex items-start justify-between gap-3">
                                        <div class="min-w-0">
                                          <p class="truncate text-sm font-semibold text-[var(--hub-text)]">
                                            <%= item.title %>
                                          </p>
                                          <p class="mt-1 text-[11px] font-medium text-[var(--hub-muted)]">
                                            <%= item.time_label %>
                                          </p>
                                        </div>
                                        <span class="fx-stamp shrink-0"><%= item.duration_label %></span>
                                      </div>

                                      <p
                                        :if={present?(item.description)}
                                        class="mt-2 text-xs leading-5 text-[var(--hub-muted)]"
                                        style="-webkit-line-clamp: 2; -webkit-box-orient: vertical; display: -webkit-box; overflow: hidden;"
                                      >
                                        <%= item.description %>
                                      </p>
                                    </div>
                                  </div>
                                </div>

                                <div
                                  :if={expanded?(@expanded_item_ids, item.id)}
                                  class={
                                    roadmap_popover_class(
                                      item.id in @expanded_item_ids,
                                      @editing_timeline_entry_id == item.record_id
                                    )
                                  }
                                  phx-click-away={roadmap_popover_click_away(@editing_timeline_entry_id == item.record_id)}
                                  phx-mounted={
                                    roadmap_popover_transition(
                                      @editing_timeline_entry_id == item.record_id
                                    )
                                  }
                                  style={
                                    roadmap_popover_style(
                                      item,
                                      @editing_timeline_entry_id == item.record_id
                                    )
                                  }
                                >
                                  <div class="fx-preview-content">
                                    <button
                                      type="button"
                                      phx-click="toggle_canvas_item"
                                      phx-value-id={item.id}
                                      class="w-full text-left"
                                    >
                                      <div class="flex items-start justify-between gap-2">
                                        <div class="min-w-0">
                                          <p class="truncate text-sm font-semibold text-[var(--hub-text)]"><%= item.title %></p>
                                          <p class="mt-1 text-[11px] font-semibold uppercase tracking-wide text-[var(--hub-secondary)]">
                                            <%= item.badge_label %>
                                          </p>
                                        </div>
                                        <span class="fx-stamp shrink-0"><%= item.duration_label %></span>
                                      </div>

                                      <p class="mt-2 text-[11px] font-medium text-[var(--hub-muted)]"><%= item.time_label %></p>
                                    </button>

                                    <%= if @editing_timeline_entry_id == item.record_id do %>
                                      <.form
                                        for={@timeline_edit_form}
                                        phx-submit="save_timeline_entry"
                                        class="mt-3 space-y-3 rounded-[1.25rem] border border-[color:var(--hub-border)] bg-[linear-gradient(180deg,rgba(36,30,56,0.97),rgba(23,22,28,0.97))] px-4 pt-4 pb-5 shadow-[0_30px_70px_-28px_rgba(109,40,217,0.62)] ring-2 ring-[color:var(--hub-accent)]/30 transition-all duration-300 ease-out"
                                      >
                                        <div class="flex items-start justify-between gap-3">
                                          <div>
                                            <p class="text-[10px] font-semibold uppercase tracking-[0.18em] text-[var(--hub-secondary)]">Edit event</p>
                                            <p class="mt-1 text-sm text-[var(--hub-muted)]">Adjust the timeline event without leaving the roadmap.</p>
                                          </div>
                                          <button
                                            type="button"
                                            phx-click="cancel_timeline_edit"
                                            class="inline-flex h-8 w-8 items-center justify-center rounded-full border border-[color:var(--hub-border)] bg-[var(--hub-surface)] text-[var(--hub-muted)] transition hover:border-[color:var(--hub-border)] hover:text-[var(--hub-text)]"
                                            aria-label="Close inline timeline editor"
                                          >
                                            <.icon name="hero-x-mark" class="h-4 w-4" />
                                          </button>
                                        </div>

                                        <div class="max-h-[24rem] space-y-3 overflow-y-auto pr-1">
                                          <div>
                                            <label for={"timeline-edit-title-#{item.record_id}"} class="mb-1 block text-[11px] font-semibold uppercase tracking-wide text-[var(--hub-muted)]">
                                              Title
                                            </label>
                                            <input
                                              id={"timeline-edit-title-#{item.record_id}"}
                                              name={@timeline_edit_form[:title].name}
                                              value={@timeline_edit_form[:title].value}
                                              type="text"
                                              class="w-full rounded-xl border border-[color:var(--hub-border)] bg-[var(--hub-surface)] px-3 py-2 text-sm text-[var(--hub-text)] outline-none transition focus:border-[color:var(--hub-accent)]/50 focus:ring-2 focus:ring-[color:var(--hub-accent)]/30"
                                            />
                                            <p :for={error <- @timeline_edit_form[:title].errors} class="mt-1 text-xs text-[var(--tone-expense)]">
                                              <%= translate_error(error) %>
                                            </p>
                                          </div>

                                          <div>
                                            <label for={"timeline-edit-description-#{item.record_id}"} class="mb-1 block text-[11px] font-semibold uppercase tracking-wide text-[var(--hub-muted)]">
                                              Description
                                            </label>
                                            <textarea
                                              id={"timeline-edit-description-#{item.record_id}"}
                                              name={@timeline_edit_form[:description].name}
                                              class="h-20 w-full rounded-xl border border-[color:var(--hub-border)] bg-[var(--hub-surface)] px-3 py-2 text-sm text-[var(--hub-text)] outline-none transition focus:border-[color:var(--hub-accent)]/50 focus:ring-2 focus:ring-[color:var(--hub-accent)]/30"
                                            ><%= @timeline_edit_form[:description].value %></textarea>
                                          </div>

                                          <div class="grid gap-3 sm:grid-cols-3">
                                            <div>
                                              <label for={"timeline-edit-kind-#{item.record_id}"} class="mb-1 block text-[11px] font-semibold uppercase tracking-wide text-[var(--hub-muted)]">
                                                Kind
                                              </label>
                                              <select
                                                id={"timeline-edit-kind-#{item.record_id}"}
                                                name={@timeline_edit_form[:kind].name}
                                                class="w-full rounded-xl border border-[color:var(--hub-border)] bg-[var(--hub-surface)] px-3 py-2 text-sm text-[var(--hub-text)] outline-none transition focus:border-[color:var(--hub-accent)]/50 focus:ring-2 focus:ring-[color:var(--hub-accent)]/30"
                                              >
                                                <option :for={{label, value} <- @milestone_kinds} value={value} selected={milestone_kind_selected?(@timeline_edit_form[:kind].value, value)}>
                                                  <%= label %>
                                                </option>
                                              </select>
                                            </div>

                                            <div>
                                              <label for={"timeline-edit-starts-at-#{item.record_id}"} class="mb-1 block text-[11px] font-semibold uppercase tracking-wide text-[var(--hub-muted)]">
                                                Starts at
                                              </label>
                                              <input
                                                id={"timeline-edit-starts-at-#{item.record_id}"}
                                                name={@timeline_edit_form[:starts_at].name}
                                                value={datetime_local_value(@timeline_edit_form[:starts_at].value)}
                                                type="datetime-local"
                                                class="w-full rounded-xl border border-[color:var(--hub-border)] bg-[var(--hub-surface)] px-3 py-2 text-sm text-[var(--hub-text)] outline-none transition focus:border-[color:var(--hub-accent)]/50 focus:ring-2 focus:ring-[color:var(--hub-accent)]/30"
                                              />
                                              <p :for={error <- @timeline_edit_form[:starts_at].errors} class="mt-1 text-xs text-[var(--tone-expense)]">
                                                <%= translate_error(error) %>
                                              </p>
                                            </div>

                                            <div>
                                              <label for={"timeline-edit-ends-at-#{item.record_id}"} class="mb-1 block text-[11px] font-semibold uppercase tracking-wide text-[var(--hub-muted)]">
                                                Ends at
                                              </label>
                                              <input
                                                id={"timeline-edit-ends-at-#{item.record_id}"}
                                                name={@timeline_edit_form[:ends_at].name}
                                                value={datetime_local_value(@timeline_edit_form[:ends_at].value)}
                                                type="datetime-local"
                                                class="w-full rounded-xl border border-[color:var(--hub-border)] bg-[var(--hub-surface)] px-3 py-2 text-sm text-[var(--hub-text)] outline-none transition focus:border-[color:var(--hub-accent)]/50 focus:ring-2 focus:ring-[color:var(--hub-accent)]/30"
                                              />
                                            </div>
                                          </div>
                                        </div>

                                        <div class="flex flex-wrap items-center justify-end gap-2">
                                          <button type="button" phx-click="cancel_timeline_edit" class="btn btn-ghost btn-xs">
                                            Cancel
                                          </button>
                                          <button type="submit" class="btn btn-primary btn-glow transition duration-300 hover:-translate-y-0.5">
                                            Save changes
                                          </button>
                                        </div>
                                      </.form>
                                    <% else %>
                                      <div class="mt-3 max-h-[9.5rem] space-y-2 overflow-y-auto pr-1 text-sm text-[var(--hub-muted)]">
                                        <p :if={present?(item.description)}><%= item.description %></p>
                                        <%= if item.item_type == :task do %>
                                          <div class="flex flex-wrap gap-2 text-[11px]">
                                            <span class="rounded-full border border-[color:var(--hub-border)] bg-[color:var(--hub-accent)]/12 px-2 py-0.5 font-medium text-[var(--hub-accent-2)]">
                                              <%= item.display_stage %>
                                            </span>
                                            <span class={priority_badge_class(item.priority)}>
                                              <%= String.upcase(item.priority) %> priority
                                            </span>
                                            <span :if={item.scheduled_for} class="rounded-full border border-[color:var(--tone-info)]/35 bg-[color:var(--tone-info)]/12 px-2 py-0.5 font-medium text-[var(--tone-info)]">
                                              Scheduled <%= Calendar.strftime(item.scheduled_for, "%b %d") %>
                                            </span>
                                            <span :if={item.due_at} class="rounded-full border border-[color:var(--tone-review)]/35 bg-[color:var(--tone-review)]/12 px-2 py-0.5 font-medium text-[var(--tone-review)]">
                                              Due <%= Calendar.strftime(item.due_at, "%b %d %I:%M %p") %>
                                            </span>
                                          </div>
                                        <% else %>
                                          <p class="text-xs text-[var(--hub-muted)]">
                                            Starts <%= Calendar.strftime(item.starts_at, "%b %d, %Y %I:%M %p") %>
                                          </p>
                                          <p :if={item.ends_at} class="text-xs text-[var(--hub-muted)]">
                                            Ends <%= Calendar.strftime(item.ends_at, "%b %d, %Y %I:%M %p") %>
                                          </p>
                                        <% end %>
                                      </div>

                                      <div class="mt-3 flex justify-end">
                                        <%= if item.item_type == :task do %>
                                          <button
                                            type="button"
                                            phx-click="focus_day_task"
                                            phx-value-id={"work-item:" <> item.record_id}
                                            data-roadmap-open-board-id={item.record_id}
                                            class="btn btn-secondary btn-xs transition duration-300 hover:-translate-y-0.5"
                                          >
                                            Open on board
                                          </button>
                                        <% else %>
                                          <button
                                            type="button"
                                            phx-click="edit_timeline_entry"
                                            phx-value-id={item.record_id}
                                            class="btn btn-secondary btn-xs transition duration-300 hover:-translate-y-0.5"
                                          >
                                            Edit
                                          </button>
                                        <% end %>
                                      </div>
                                    <% end %>
                                  </div>
                                </div>
                              </div>
                            </div>
                          </section>
                          </div>
                        </div>
                      <% end %>
                    </div>
                  </div>

                  <div class="mt-6">
                    <div class="mb-4 flex items-end justify-between gap-4 px-1">
                      <div>
                        <p class="text-xs font-semibold uppercase tracking-[0.24em] text-[var(--hub-muted)]">Stage</p>
                      </div>
                    </div>

                    <div class="grid gap-4 xl:grid-cols-4">
                    <section
                      :for={stage <- @canvas_stages}
                      class="relative overflow-visible rounded-[1.75rem] border border-[color:var(--hub-border)] bg-[linear-gradient(180deg,rgba(255,255,255,0.045),rgba(139,92,246,0.06))] p-4 shadow-sm"
                    >
                      <div class="flex items-center justify-between gap-3">
                        <h3 class="text-lg font-semibold text-[var(--hub-text)]"><%= lane_title(stage) %></h3>
                        <span class="rounded-full border border-[color:var(--hub-border)] bg-[color:var(--hub-accent)]/12 px-2.5 py-1 text-xs font-semibold text-[var(--hub-secondary)]">
                          <%= length(Map.get(@canvas_stage_items, stage, [])) %>
                        </span>
                      </div>

                      <div
                        class="relative mt-5 overflow-visible rounded-2xl border border-[color:var(--hub-border)] bg-[linear-gradient(180deg,rgba(139,92,246,0.12),rgba(139,92,246,0.05))] px-4 py-4"
                        data-stage-canvas={stage}
                        style={stage_canvas_style(Map.get(@canvas_stage_items, stage, []), @expanded_item_ids)}
                      >

                        <%= if Map.get(@canvas_stage_items, stage, []) == [] do %>
                          <div
                            class="min-h-[16rem] rounded-xl border border-dashed border-[color:var(--hub-accent)]/20 bg-[color:var(--hub-accent)]/5"
                            data-stage-empty-state={stage}
                            aria-hidden="true"
                          >
                          </div>
                        <% else %>
                          <button
                            :if={stage_has_expanded_item?(Map.get(@canvas_stage_items, stage, []), @expanded_item_ids)}
                            type="button"
                            phx-click="close_stage_items"
                            class="absolute inset-0 z-20 cursor-default rounded-2xl bg-transparent"
                            aria-label={"Close expanded #{lane_title(stage)} cards"}
                          >
                          </button>

                          <div
                            :for={item <- Map.get(@canvas_stage_items, stage, [])}
                            class={stage_item_container_class(expanded?(@expanded_item_ids, item.id))}
                            style={stage_item_position_style(item, expanded?(@expanded_item_ids, item.id))}
                          >
                            <div class="fx-item group/stage relative h-full">
                              <div
                                class={stage_focus_backdrop_class(expanded?(@expanded_item_ids, item.id))}
                                style={
                                  stage_focus_backdrop_style(
                                    item,
                                    Map.get(@canvas_stage_items, stage, []),
                                    @expanded_item_ids
                                  )
                                }
                              >
                              </div>

                              <span
                                data-stage-item-id={item.id}
                                class={stage_dot_class(stage, expanded?(@expanded_item_ids, item.id))}
                                aria-hidden="true"
                              >
                              </span>

                              <div class={stage_title_rail_class(expanded?(@expanded_item_ids, item.id))}>
                                <p class="truncate"><%= item.title %></p>
                              </div>

                              <div
                                :if={!expanded?(@expanded_item_ids, item.id)}
                                class={stage_preview_class()}
                                style={stage_preview_style(stage)}
                              >
                                <div class="fx-preview-content">
                                  <div class="flex items-start justify-between gap-3">
                                    <div class="min-w-0">
                                      <p class="truncate text-sm font-semibold text-[var(--hub-text)]"><%= item.title %></p>
                                      <p
                                        :if={present?(item.description)}
                                        class="mt-1 text-xs leading-5 text-[var(--hub-muted)]"
                                        style="-webkit-line-clamp: 2; -webkit-box-orient: vertical; display: -webkit-box; overflow: hidden;"
                                      >
                                        <%= item.description %>
                                      </p>
                                    </div>
                                    <span class="fx-stamp shrink-0"><%= lane_title(item.status) %></span>
                                  </div>

                                  <div class="mt-3 flex flex-wrap gap-2 text-[11px]">
                                    <span class={priority_badge_class(item.priority)}>
                                      <%= String.upcase(item.priority) %>
                                    </span>
                                    <span :if={item.scheduled_for} class="rounded-full border border-[color:var(--tone-info)]/35 bg-[color:var(--tone-info)]/12 px-2 py-0.5 font-medium text-[var(--tone-info)]">
                                      Scheduled <%= Calendar.strftime(item.scheduled_for, "%b %d") %>
                                    </span>
                                    <span :if={item.due_at} class="rounded-full border border-[color:var(--tone-review)]/35 bg-[color:var(--tone-review)]/12 px-2 py-0.5 font-medium text-[var(--tone-review)]">
                                      Due <%= Calendar.strftime(item.due_at, "%b %d %I:%M %p") %>
                                    </span>
                                  </div>

                                  <div class="mt-3 flex justify-end">
                                    <button
                                      type="button"
                                      phx-click="toggle_canvas_item"
                                      phx-value-id={item.id}
                                      data-stage-open-id={item.id}
                                      class="btn btn-secondary btn-xs transition duration-300 hover:-translate-y-0.5"
                                    >
                                      Open task
                                    </button>
                                  </div>
                                </div>
                              </div>

                              <div
                                :if={expanded?(@expanded_item_ids, item.id)}
                                class={stage_popover_class()}
                                phx-click-away="close_stage_items"
                                phx-mounted={stage_popover_transition()}
                                style={stage_popover_style(stage)}
                              >
                                <div class="fx-preview-content">
                                  <button
                                    type="button"
                                    phx-click="toggle_canvas_item"
                                    phx-value-id={item.id}
                                    class="w-full text-left"
                                  >
                                    <div class="flex items-start justify-between gap-3">
                                      <div class="min-w-0">
                                        <p class="truncate text-sm font-semibold text-[var(--hub-text)]"><%= item.title %></p>
                                        <p class="mt-1 text-[11px] font-semibold uppercase tracking-wide text-[var(--hub-secondary)]">
                                          <%= lane_title(item.status) %> task
                                        </p>
                                      </div>
                                      <span class="fx-stamp shrink-0"><%= item.sequence %></span>
                                    </div>

                                    <div class="mt-3 flex flex-wrap gap-2 text-[11px]">
                                      <span class={priority_badge_class(item.priority)}>
                                        <%= String.upcase(item.priority) %> priority
                                      </span>
                                      <span :if={item.scheduled_for} class="rounded-full border border-[color:var(--tone-info)]/35 bg-[color:var(--tone-info)]/12 px-2 py-0.5 font-medium text-[var(--tone-info)]">
                                        Scheduled <%= Calendar.strftime(item.scheduled_for, "%b %d") %>
                                      </span>
                                      <span :if={item.due_at} class="rounded-full border border-[color:var(--tone-review)]/35 bg-[color:var(--tone-review)]/12 px-2 py-0.5 font-medium text-[var(--tone-review)]">
                                        Due <%= Calendar.strftime(item.due_at, "%b %d %I:%M %p") %>
                                      </span>
                                    </div>
                                  </button>

                                  <div class="mt-3 space-y-3">
                                    <p :if={present?(item.description)} class="text-sm leading-6 text-[var(--hub-muted)]"><%= item.description %></p>

                                    <div class="flex flex-wrap gap-2">
                                      <button
                                        :for={action <- transition_actions(item.status)}
                                        type="button"
                                        phx-click="transition_work_item"
                                        phx-value-id={item.record_id}
                                        phx-value-to={action.to}
                                        class={action.button_class}
                                      >
                                        <%= action.label %>
                                      </button>
                                    </div>
                                  </div>
                                </div>
                              </div>
                            </div>
                          </div>
                        <% end %>
                      </div>
                    </section>
                    </div>
                  </div>

                  <div class="mt-6 grid gap-4 md:grid-cols-2 xl:grid-cols-4">
                    <div :for={item <- @agenda_items} class="hub-glass rounded-2xl p-4">
                      <p class="text-xs font-semibold uppercase tracking-wide text-[var(--hub-muted)]"><%= item.badge %></p>
                      <h3 class="mt-2 text-sm font-semibold text-[var(--hub-text)]"><%= item.title %></h3>
                      <p class="mt-1 text-xs text-[var(--hub-muted)]"><%= item.when_label %></p>
                    </div>
                  </div>
                </div>

                <aside class="space-y-4">
                  <section class="rounded-[1.75rem] border border-[color:var(--hub-border)] bg-[linear-gradient(180deg,rgba(36,30,56,0.97),rgba(23,22,28,0.97))] p-5 shadow-sm">
                    <div class="flex items-center justify-between gap-3">
                      <div>
                        <p class="text-xs font-semibold uppercase tracking-wide text-[var(--hub-secondary)]">Calendar</p>
                        <h2 class="mt-1 text-lg font-semibold text-[var(--hub-text)]"><%= calendar_month_label(@calendar_month) %></h2>
                      </div>

                      <div class="flex items-center gap-2">
                        <button type="button" phx-click="prev_calendar_month" class="btn btn-ghost btn-xs">Prev</button>
                        <button type="button" phx-click="next_calendar_month" class="btn btn-ghost btn-xs">Next</button>
                      </div>
                    </div>

                    <div class="mt-4 grid grid-cols-7 gap-1 text-center text-[10px] font-semibold uppercase tracking-[0.18em] text-[var(--hub-muted)]">
                      <span :for={label <- @calendar_weekdays}><%= label %></span>
                    </div>

                    <div class="mt-3 grid grid-cols-7 gap-1.5">
                      <button
                        :for={day <- @calendar_days}
                        type="button"
                        phx-click="select_calendar_date"
                        phx-value-date={Date.to_iso8601(day.date)}
                        class={calendar_day_class(day)}
                      >
                        <span class="text-xs font-semibold"><%= day.label %></span>
                        <span :if={day.has_items?} class={calendar_dot_class(day.total_count)}></span>
                      </button>
                    </div>

                    <div class="mt-4 flex items-center justify-between gap-3 border-t border-[color:var(--hub-border)] pt-4">
                      <div>
                        <p class="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--hub-muted)]">Focus</p>
                        <p class="mt-1 text-sm font-semibold text-[var(--hub-text)]"><%= calendar_focus_label(@selected_date) %></p>
                      </div>
                      <button
                        :if={@selected_date}
                        type="button"
                        phx-click="clear_calendar_date"
                        class="btn btn-secondary btn-xs"
                      >
                        All days
                      </button>
                    </div>

                    <div class="hub-glass mt-4 rounded-2xl p-4">
                      <div class="flex items-center justify-between gap-3">
                        <p class="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--hub-muted)]">
                          <%= selected_day_heading(@selected_date) %>
                        </p>
                        <button
                          :if={@selected_date}
                          type="button"
                          phx-click="toggle_selected_day_entry_form"
                          class="inline-flex h-8 w-8 items-center justify-center rounded-full border border-[color:var(--hub-border)] bg-[var(--hub-surface)] text-base font-semibold leading-none text-[var(--hub-accent-2)] shadow-sm transition duration-200 hover:-translate-y-0.5 hover:border-[color:var(--hub-accent)]/50 hover:text-[var(--hub-accent-2)]"
                          data-selected-day-add-entry="true"
                          aria-label="Toggle task form for selected date"
                        >
                          +
                        </button>
                      </div>
                      <p class="mt-2 text-2xl font-semibold text-[var(--hub-text)]"><%= @selected_day_summary.total_count %></p>
                      <p class="mt-1 text-sm text-[var(--hub-muted)]">planned items</p>

                      <div class="mt-4 grid grid-cols-2 gap-3 text-sm">
                        <div class="rounded-xl border border-[color:var(--hub-border)] bg-[color:var(--hub-accent)]/12 px-3 py-2">
                          <p class="text-[10px] font-semibold uppercase tracking-[0.18em] text-[var(--hub-muted)]">Tasks</p>
                          <p class="mt-1 font-semibold text-[var(--hub-text)]"><%= @selected_day_summary.task_count %></p>
                        </div>
                        <div class="rounded-xl border border-[color:var(--hub-border)] bg-[color:var(--hub-accent)]/12 px-3 py-2">
                          <p class="text-[10px] font-semibold uppercase tracking-[0.18em] text-[var(--hub-muted)]">Events</p>
                          <p class="mt-1 font-semibold text-[var(--hub-text)]"><%= @selected_day_summary.event_count %></p>
                        </div>
                      </div>

                      <div class="mt-4 border-t border-[color:var(--hub-border)] pt-4">
                        <div class="flex items-center justify-between gap-3">
                          <p class="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--hub-muted)]">Tasks for the day</p>
                          <span class="text-xs font-medium text-[var(--hub-muted)]"><%= length(@selected_day_tasks) %></span>
                        </div>

                        <div :if={@selected_date == nil} class="mt-3 rounded-xl border border-dashed border-[color:var(--hub-accent)]/20 bg-[color:var(--hub-accent)]/5 px-3 py-3 text-sm text-[var(--hub-muted)]">
                          Select a date to inspect and open its tasks.
                        </div>

                        <div
                          :if={@selected_date && @selected_day_tasks == []}
                          class="mt-3 min-h-[6rem] rounded-xl border border-dashed border-[color:var(--hub-accent)]/20 bg-[color:var(--hub-accent)]/5 px-3 py-3"
                          data-selected-day-empty-state="tasks"
                          aria-hidden="true"
                        >
                        </div>

                        <div :if={@selected_day_tasks != []} class="mt-3 space-y-2">
                          <div
                            :for={task <- @selected_day_tasks}
                            class="w-full rounded-xl border border-[color:var(--hub-border)] bg-[linear-gradient(180deg,rgba(36,30,56,0.97),rgba(23,22,28,0.97))] px-3 py-3 text-left transition duration-300 hover:-translate-y-0.5 hover:border-[color:var(--hub-border)] hover:shadow-sm"
                          >
                            <div class="flex items-start justify-between gap-3">
                              <div class="min-w-0">
                                <p class="truncate text-sm font-semibold text-[var(--hub-text)]"><%= task.title %></p>
                                <p :if={present?(task.description)} class="mt-1 line-clamp-2 text-xs leading-5 text-[var(--hub-muted)]">
                                  <%= task.description %>
                                </p>
                              </div>
                              <span class="rounded-full border border-[color:var(--hub-border)] bg-[color:var(--hub-accent)]/12 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-[var(--hub-secondary)]">
                                <%= lane_title(task.status) %>
                              </span>
                            </div>

                            <div class="mt-3 flex flex-wrap items-center gap-2 text-[11px]">
                              <span class={priority_badge_class(task.priority)}><%= String.upcase(task.priority) %></span>
                              <span :if={task.scheduled_for} class="rounded-full border border-[color:var(--tone-info)]/35 bg-[color:var(--tone-info)]/12 px-2 py-0.5 font-medium text-[var(--tone-info)]">
                                Scheduled <%= Calendar.strftime(task.scheduled_for, "%b %d") %>
                              </span>
                              <span :if={task.due_at} class="rounded-full border border-[color:var(--tone-review)]/35 bg-[color:var(--tone-review)]/12 px-2 py-0.5 font-medium text-[var(--tone-review)]">
                                Due <%= Calendar.strftime(task.due_at, "%b %d %I:%M %p") %>
                              </span>
                            </div>

                            <div class="mt-3 flex items-center justify-end">
                              <button
                                type="button"
                                phx-click="toggle_day_task_details"
                                phx-value-id={task.id}
                                class="btn btn-secondary btn-xs"
                              >
                                <%= if expanded?(@selected_day_expanded_task_ids, task.id), do: "Hide details", else: "Details" %>
                              </button>
                            </div>

                            <div
                              :if={expanded?(@selected_day_expanded_task_ids, task.id)}
                              class="mt-3 rounded-xl border border-[color:var(--hub-border)] bg-[var(--hub-surface)] px-3 py-3 text-sm text-[var(--hub-muted)]"
                            >
                              <p :if={present?(task.description)} class="leading-6"><%= task.description %></p>
                              <div class="mt-3 grid gap-2 text-xs text-[var(--hub-muted)]">
                                <p>Stage: <span class="font-semibold text-[var(--hub-text)]"><%= lane_title(task.status) %></span></p>
                                <p :if={task.scheduled_for}>
                                  Scheduled for <span class="font-semibold text-[var(--hub-text)]"><%= Calendar.strftime(task.scheduled_for, "%b %d, %Y") %></span>
                                </p>
                                <p :if={task.due_at}>
                                  Due at <span class="font-semibold text-[var(--hub-text)]"><%= Calendar.strftime(task.due_at, "%b %d, %Y %I:%M %p") %></span>
                                </p>
                              </div>
                            </div>
                          </div>
                        </div>
                      </div>
                    </div>

                    <div
                      :if={@selected_date && @selected_day_entry_form_open}
                      class="hub-glass mt-3 rounded-2xl p-4"
                    >
                      <.form
                        for={@selected_day_entry_form}
                        phx-submit="create_selected_day_task"
                        class="space-y-3"
                      >
                        <div class="flex items-start justify-between gap-3">
                          <div>
                            <p class="text-xs font-semibold uppercase tracking-wide text-[var(--hub-muted)]">Quick task</p>
                            <p class="mt-1 text-sm font-semibold text-[var(--hub-text)]">
                              Scheduled for <%= calendar_focus_label(@selected_date) %>
                            </p>
                          </div>
                          <button
                            type="button"
                            phx-click="cancel_selected_day_entry_form"
                            class="inline-flex h-8 w-8 items-center justify-center rounded-full border border-[color:var(--hub-border)] bg-[var(--hub-surface)] text-[var(--hub-muted)] transition hover:border-[color:var(--hub-border)] hover:text-[var(--hub-text)]"
                            aria-label="Close selected day task form"
                          >
                            <.icon name="hero-x-mark" class="h-4 w-4" />
                          </button>
                        </div>

                        <div>
                          <label
                            for="selected-day-entry-title"
                            class="mb-1 block text-[11px] font-semibold uppercase tracking-wide text-[var(--hub-muted)]"
                          >
                            Title
                          </label>
                          <input
                            id="selected-day-entry-title"
                            name={@selected_day_entry_form[:title].name}
                            value={@selected_day_entry_form[:title].value}
                            type="text"
                            placeholder="Add task title"
                            class="w-full rounded-xl border border-[color:var(--hub-border)] bg-[var(--hub-surface)] px-4 py-3 text-sm text-[var(--hub-text)] outline-none transition focus:border-[color:var(--hub-accent)]/50 focus:ring-2 focus:ring-[color:var(--hub-accent)]/30"
                          />
                          <p
                            :for={error <- @selected_day_entry_form[:title].errors}
                            class="mt-1 text-xs text-[var(--tone-expense)]"
                          >
                            <%= translate_error(error) %>
                          </p>
                        </div>

                        <div>
                          <label
                            for="selected-day-entry-description"
                            class="mb-1 block text-[11px] font-semibold uppercase tracking-wide text-[var(--hub-muted)]"
                          >
                            Description
                          </label>
                          <textarea
                            id="selected-day-entry-description"
                            name={@selected_day_entry_form[:description].name}
                            class="h-20 w-full rounded-xl border border-[color:var(--hub-border)] bg-[var(--hub-surface)] px-4 py-3 text-sm text-[var(--hub-text)] outline-none transition focus:border-[color:var(--hub-accent)]/50 focus:ring-2 focus:ring-[color:var(--hub-accent)]/30"
                            placeholder="Add context or notes"
                          ><%= @selected_day_entry_form[:description].value %></textarea>
                        </div>

                        <div class="grid gap-3 sm:grid-cols-2">
                          <div>
                            <label
                              for="selected-day-entry-priority"
                              class="mb-1 block text-[11px] font-semibold uppercase tracking-wide text-[var(--hub-muted)]"
                            >
                              Priority
                            </label>
                            <select
                              id="selected-day-entry-priority"
                              name={@selected_day_entry_form[:priority].name}
                              class="w-full rounded-xl border border-[color:var(--hub-border)] bg-[var(--hub-surface)] px-4 py-3 text-sm text-[var(--hub-text)] outline-none transition focus:border-[color:var(--hub-accent)]/50 focus:ring-2 focus:ring-[color:var(--hub-accent)]/30"
                            >
                              <option
                                value="low"
                                selected={@selected_day_entry_form[:priority].value == "low"}
                              >
                                Low
                              </option>
                              <option
                                value="medium"
                                selected={@selected_day_entry_form[:priority].value in [nil, "medium"]}
                              >
                                Medium
                              </option>
                              <option
                                value="high"
                                selected={@selected_day_entry_form[:priority].value == "high"}
                              >
                                High
                              </option>
                            </select>
                          </div>

                          <div>
                            <label
                              for="selected-day-entry-due-at"
                              class="mb-1 block text-[11px] font-semibold uppercase tracking-wide text-[var(--hub-muted)]"
                            >
                              Due at
                            </label>
                            <input
                              id="selected-day-entry-due-at"
                              name={@selected_day_entry_form[:due_at].name}
                              value={datetime_local_value(@selected_day_entry_form[:due_at].value)}
                              type="datetime-local"
                              class="w-full rounded-xl border border-[color:var(--hub-border)] bg-[var(--hub-surface)] px-4 py-3 text-sm text-[var(--hub-text)] outline-none transition focus:border-[color:var(--hub-accent)]/50 focus:ring-2 focus:ring-[color:var(--hub-accent)]/30"
                            />
                            <p
                              :for={error <- @selected_day_entry_form[:due_at].errors}
                              class="mt-1 text-xs text-[var(--tone-expense)]"
                            >
                              <%= translate_error(error) %>
                            </p>
                          </div>
                        </div>

                        <div class="flex items-center justify-end gap-2">
                          <button
                            type="button"
                            phx-click="cancel_selected_day_entry_form"
                            class="btn btn-ghost btn-xs"
                          >
                            Cancel
                          </button>
                          <button type="submit" class="btn btn-primary btn-xs">Create task</button>
                        </div>
                      </.form>
                    </div>
                  </section>
                </aside>
              </div>
            </div>
          </section>
        </main>
      </div>
    </Layouts.app>
    """
  end

  defp assign_workbench(socket) do
    workbench = Office.list_workbench_for_project(socket.assigns.current_project)
    canvas = workbench.canvas
    calendar_details = calendar_details(workbench)
    selected_date = socket.assigns.selected_date

    roadmap_rows =
      roadmap_rows(roadmap_schedule_items(canvas.milestones, workbench.work_items), selected_date)

    expanded_item_ids =
      prune_expanded_items(socket.assigns.expanded_item_ids, canvas, roadmap_rows)

    roadmap_item_ids = Enum.flat_map(roadmap_rows, fn row -> Enum.map(row.items, & &1.id) end)

    selected_day_tasks = selected_day_tasks(selected_date, workbench.work_items)
    selected_day_task_ids = Enum.map(selected_day_tasks, & &1.id)

    assign(socket,
      calendar_days:
        calendar_days(socket.assigns.calendar_month, calendar_details, selected_date),
      calendar_weekdays: @calendar_weekdays,
      canvas_stages: Office.canvas_stages(),
      canvas_stage_items: canvas.stage_items,
      canvas_milestones: canvas.milestones,
      canvas_item_count:
        Enum.reduce(canvas.stage_items, 0, fn {_stage, items}, acc -> acc + length(items) end),
      agenda_items: agenda_items(workbench),
      roadmap_hour_ticks: roadmap_hour_ticks(),
      roadmap_item_ids: roadmap_item_ids,
      roadmap_rows: roadmap_rows,
      current_project_summary: Office.project_summary(socket.assigns.current_project),
      selected_day_summary: selected_day_summary(selected_date, calendar_details),
      selected_day_tasks: selected_day_tasks,
      selected_day_expanded_task_ids:
        Enum.filter(socket.assigns.selected_day_expanded_task_ids, &(&1 in selected_day_task_ids)),
      expanded_item_ids: expanded_item_ids,
      milestone_kinds: @milestone_kinds
    )
  end

  defp assign_entry_form(socket, kind \\ @default_entry_kind, attrs \\ %{}) do
    attrs =
      case kind do
        "milestone" -> Map.put_new(attrs, "kind", "milestone")
        _ -> attrs
      end

    changeset =
      case kind do
        "milestone" -> Office.timeline_entry_changeset(attrs)
        _ -> Office.planner_changeset(attrs)
      end

    assign(socket,
      entry_kind: kind,
      entry_form: to_form(changeset, as: :entry),
      milestone_kinds: @milestone_kinds
    )
  end

  defp assign_selected_day_entry_form(socket, attrs \\ %{}) do
    assign(socket,
      selected_day_entry_form: to_form(Office.planner_changeset(attrs), as: :selected_day_entry)
    )
  end

  defp assign_project_form(socket, attrs \\ %{}) do
    assign(socket, project_form: to_form(Office.project_changeset(attrs), as: :project))
  end

  defp selected_date_task_attrs(%Date{} = selected_date) do
    %{"scheduled_for" => Date.to_iso8601(selected_date)}
  end

  defp selected_date_task_attrs(_selected_date), do: %{}

  defp create_task(socket, user, project, params) do
    case Office.create_work_item(user, project, params) do
      {:ok, work_item} ->
        {:noreply,
         socket
         |> put_flash(:info, "Task added to roadmap")
         |> assign(entry_form_open: false, expanded_item_ids: ["work-item:" <> work_item.id])
         |> assign_entry_form()
         |> assign_workbench()}

      {:error, %Ecto.Changeset{} = _changeset} ->
        {:noreply,
         socket
         |> assign(entry_form_open: true)
         |> assign_entry_form("task", params)}
    end
  end

  defp create_milestone(socket, user, project, params) do
    case Office.create_timeline_entry(user, project, params) do
      {:ok, entry} ->
        {:noreply,
         socket
         |> put_flash(:info, "Milestone added to roadmap")
         |> assign(entry_form_open: false, expanded_item_ids: ["timeline-entry:" <> entry.id])
         |> assign_entry_form()
         |> assign_workbench()}

      {:error, %Ecto.Changeset{} = _changeset} ->
        {:noreply,
         socket
         |> assign(entry_form_open: true)
         |> assign_entry_form("milestone", params)}
    end
  end

  defp agenda_items(workbench) do
    task_items =
      Enum.flat_map(workbench.work_items, fn work_item ->
        []
        |> maybe_add_scheduled_item(work_item)
        |> maybe_add_due_item(work_item)
      end)

    milestone_items =
      Enum.map(workbench.timeline_entries, fn entry ->
        %{
          badge: timeline_kind_label(entry.kind),
          title: entry.title,
          when_label: "Starts " <> Calendar.strftime(entry.starts_at, "%b %d %I:%M %p"),
          sort_key: {2, NaiveDateTime.to_erl(entry.starts_at)}
        }
      end)

    (task_items ++ milestone_items)
    |> Enum.sort_by(& &1.sort_key)
    |> Enum.take(4)
    |> Enum.map(&Map.delete(&1, :sort_key))
  end

  defp maybe_add_scheduled_item(items, work_item) do
    if is_struct(work_item.scheduled_for, Date) do
      [
        %{
          badge: lane_title(work_item.status),
          title: work_item.title,
          when_label: "Scheduled " <> Calendar.strftime(work_item.scheduled_for, "%b %d"),
          sort_key: {0, Date.to_erl(work_item.scheduled_for)}
        }
        | items
      ]
    else
      items
    end
  end

  defp maybe_add_due_item(items, work_item) do
    if is_struct(work_item.due_at, NaiveDateTime) do
      [
        %{
          badge: "Due",
          title: work_item.title,
          when_label: "Due " <> Calendar.strftime(work_item.due_at, "%b %d %I:%M %p"),
          sort_key: {1, NaiveDateTime.to_erl(work_item.due_at)}
        }
        | items
      ]
    else
      items
    end
  end

  defp roadmap_hour_ticks do
    total_minutes = roadmap_window_minutes()

    Enum.map(@roadmap_start_hour..@roadmap_end_hour, fn hour ->
      %{
        label: format_hour_label(hour),
        position_percent: Float.round((hour - @roadmap_start_hour) * 60 / total_minutes * 100, 2)
      }
    end)
  end

  defp roadmap_schedule_items(milestones, work_items) do
    milestone_items =
      Enum.map(milestones, fn item ->
        item
        |> Map.put(:badge_label, roadmap_badge_label(item))
        |> Map.put(:display_stage, nil)
      end)

    task_items =
      Enum.flat_map(work_items, fn work_item ->
        case roadmap_task_schedule(work_item) do
          nil ->
            []

          {starts_at, ends_at, schedule_source} ->
            [
              %{
                id: "roadmap-work-item:" <> work_item.id,
                item_type: :task,
                kind: "task",
                status: work_item.status,
                priority: work_item.priority,
                title: work_item.title,
                description: work_item.description,
                scheduled_for: work_item.scheduled_for,
                due_at: work_item.due_at,
                starts_at: starts_at,
                ends_at: ends_at,
                record_id: work_item.id,
                schedule_source: schedule_source,
                badge_label: roadmap_badge_label(%{item_type: :task, status: work_item.status}),
                display_stage: lane_title(work_item.status)
              }
            ]
        end
      end)

    milestone_items ++ task_items
  end

  defp roadmap_rows([], _selected_date), do: []

  defp roadmap_rows(items, selected_date) do
    items
    |> maybe_filter_roadmap_items(selected_date)
    |> Enum.group_by(fn item -> NaiveDateTime.to_date(item.starts_at) end)
    |> Enum.sort_by(fn {date, _items} -> Date.to_erl(date) end)
    |> Enum.map(fn {date, day_items} ->
      laid_out_items =
        day_items
        |> TimelineLayout.layout()
        |> Enum.map(&annotate_roadmap_schedule_item/1)

      lane_count =
        laid_out_items
        |> Enum.map(& &1.lane_count)
        |> Enum.max(fn -> 1 end)

      %{
        date: date,
        weekday_label: Calendar.strftime(date, "%a"),
        date_label: Calendar.strftime(date, "%b %d"),
        height_rem: max(lane_count * 5.5 + 1.5, 6.5),
        items: laid_out_items
      }
    end)
  end

  defp maybe_filter_roadmap_items(items, nil), do: items

  defp maybe_filter_roadmap_items(items, %Date{} = selected_date) do
    Enum.filter(items, fn item ->
      Date.compare(NaiveDateTime.to_date(item.starts_at), selected_date) == :eq
    end)
  end

  defp calendar_details(workbench) do
    workbench.work_items
    |> Enum.reduce(%{}, fn work_item, acc ->
      acc
      |> maybe_track_task_date(work_item.id, work_item.scheduled_for)
      |> maybe_track_task_date(work_item.id, due_date(work_item.due_at))
    end)
    |> then(fn acc ->
      Enum.reduce(workbench.timeline_entries, acc, fn entry, inner_acc ->
        track_event_date(inner_acc, entry.id, NaiveDateTime.to_date(entry.starts_at))
      end)
    end)
    |> Enum.into(%{}, fn {date, detail} ->
      task_count = MapSet.size(detail.tasks)
      event_count = MapSet.size(detail.events)

      {date,
       %{
         task_count: task_count,
         event_count: event_count,
         total_count: task_count + event_count
       }}
    end)
  end

  defp maybe_track_task_date(details, _task_id, nil), do: details

  defp maybe_track_task_date(details, task_id, %Date{} = date) do
    Map.update(details, date, %{tasks: MapSet.new([task_id]), events: MapSet.new()}, fn detail ->
      %{detail | tasks: MapSet.put(detail.tasks, task_id)}
    end)
  end

  defp track_event_date(details, event_id, %Date{} = date) do
    Map.update(details, date, %{tasks: MapSet.new(), events: MapSet.new([event_id])}, fn detail ->
      %{detail | events: MapSet.put(detail.events, event_id)}
    end)
  end

  defp calendar_days(calendar_month, details, selected_date) do
    grid_start = calendar_grid_start(calendar_month)

    Enum.map(0..41, fn offset ->
      date = Date.add(grid_start, offset)
      summary = Map.get(details, date, empty_day_summary())

      %{
        date: date,
        has_items?: summary.total_count > 0,
        in_month?: date.month == calendar_month.month and date.year == calendar_month.year,
        label: Integer.to_string(date.day),
        selected?: selected_date && Date.compare(date, selected_date) == :eq,
        total_count: summary.total_count
      }
    end)
  end

  defp selected_day_summary(nil, details) do
    details
    |> Map.values()
    |> Enum.reduce(empty_day_summary(), fn detail, acc ->
      %{
        task_count: acc.task_count + detail.task_count,
        event_count: acc.event_count + detail.event_count,
        total_count: acc.total_count + detail.total_count
      }
    end)
  end

  defp selected_day_summary(%Date{} = selected_date, details) do
    Map.get(details, selected_date, empty_day_summary())
  end

  defp selected_day_tasks(nil, _work_items), do: []

  defp selected_day_tasks(%Date{} = selected_date, work_items) do
    work_items
    |> Enum.filter(&task_on_date?(&1, selected_date))
    |> Enum.sort_by(fn task ->
      {
        task_date_sort_key(task.scheduled_for),
        task_datetime_sort_key(task.due_at),
        task.inserted_at
      }
    end)
    |> Enum.map(&Map.put(&1, :id, "work-item:" <> &1.id))
  end

  defp task_on_date?(task, %Date{} = selected_date) do
    task_matches_date?(task.scheduled_for, selected_date) or
      task_matches_date?(due_date(task.due_at), selected_date)
  end

  defp task_matches_date?(nil, _selected_date), do: false

  defp task_matches_date?(%Date{} = date, %Date{} = selected_date) do
    Date.compare(date, selected_date) == :eq
  end

  defp task_date_sort_key(nil), do: ~D[9999-12-31]
  defp task_date_sort_key(%Date{} = date), do: date

  defp task_datetime_sort_key(nil), do: ~N[9999-12-31 23:59:59]
  defp task_datetime_sort_key(%NaiveDateTime{} = value), do: value

  defp empty_day_summary do
    %{task_count: 0, event_count: 0, total_count: 0}
  end

  defp due_date(nil), do: nil
  defp due_date(%NaiveDateTime{} = due_at), do: NaiveDateTime.to_date(due_at)

  defp timeline_entry_attrs(timeline_entry) do
    %{
      "title" => timeline_entry.title,
      "description" => timeline_entry.description,
      "kind" => timeline_entry.kind,
      "starts_at" => datetime_local_value(timeline_entry.starts_at),
      "ends_at" => datetime_local_value(timeline_entry.ends_at)
    }
  end

  defp maybe_focus_date(socket, %Date{} = date) do
    assign(socket, selected_date: date, calendar_month: month_start(date))
  end

  defp calendar_grid_start(calendar_month) do
    offset = rem(Date.day_of_week(calendar_month), 7)
    Date.add(calendar_month, -offset)
  end

  defp month_start(%Date{} = date) do
    %{date | day: 1}
  end

  defp previous_month(%Date{} = current_month) do
    current_month
    |> Date.add(-1)
    |> month_start()
  end

  defp next_month(%Date{} = current_month) do
    current_month
    |> Date.add(Date.days_in_month(current_month))
    |> month_start()
  end

  defp calendar_month_label(%Date{} = date), do: Calendar.strftime(date, "%B %Y")

  defp calendar_day_class(day) do
    base =
      "flex h-12 flex-col items-center justify-center rounded-2xl border transition duration-300"

    cond do
      day.selected? ->
        base <>
          " border-[color:var(--hub-accent)]/50 bg-[color:var(--hub-accent)]/20 text-[var(--hub-text)] shadow-sm"

      day.in_month? ->
        base <>
          " border-[color:var(--hub-border)] bg-[var(--hub-surface)] text-[var(--hub-text)] hover:border-[color:var(--hub-accent)]/40 hover:bg-[color:var(--hub-accent)]/12"

      true ->
        base <>
          " border-transparent bg-transparent text-[color:var(--hub-muted)]/45 hover:border-[color:var(--hub-border)] hover:bg-[color:var(--hub-accent)]/10"
    end
  end

  defp calendar_dot_class(total_count) when total_count <= 2,
    do: "mt-1 h-2.5 w-2.5 rounded-full bg-[var(--tone-income)]"

  defp calendar_dot_class(total_count) when total_count <= 4,
    do: "mt-1 h-2.5 w-2.5 rounded-full bg-[var(--tone-review)]"

  defp calendar_dot_class(_total_count),
    do: "mt-1 h-2.5 w-2.5 rounded-full bg-[var(--tone-expense)]"

  defp calendar_focus_label(nil), do: "All roadmap days"

  defp calendar_focus_label(%Date{} = selected_date),
    do: Calendar.strftime(selected_date, "%b %d, %Y")

  defp selected_day_heading(nil), do: "All planned days"
  defp selected_day_heading(%Date{} = selected_date), do: Calendar.strftime(selected_date, "%A")

  defp empty_roadmap_message(nil),
    do: "Add a task or milestone to place a dot on the roadmap track."

  defp empty_roadmap_message(%Date{} = selected_date) do
    "No scheduled roadmap items on " <> Calendar.strftime(selected_date, "%b %d") <> " yet."
  end

  defp annotate_roadmap_schedule_item(item) do
    item
    |> Map.put_new(:badge_label, roadmap_badge_label(item))
    |> Map.put(:duration_label, roadmap_duration_label(item.starts_at, item.ends_at))
    |> Map.put(:time_label, roadmap_time_label(item.starts_at, item.ends_at))
  end

  defp roadmap_task_schedule(%{
         due_at: %NaiveDateTime{} = due_at,
         scheduled_for: %Date{} = scheduled_for
       }) do
    if Date.compare(NaiveDateTime.to_date(due_at), scheduled_for) == :eq do
      {scheduled_task_starts_at(scheduled_for), due_at, :scheduled_span}
    else
      {due_at, nil, :due}
    end
  end

  defp roadmap_task_schedule(%{due_at: %NaiveDateTime{} = due_at}), do: {due_at, nil, :due}

  defp roadmap_task_schedule(%{scheduled_for: %Date{} = scheduled_for}) do
    {scheduled_task_starts_at(scheduled_for), nil, :scheduled}
  end

  defp roadmap_task_schedule(_work_item), do: nil

  defp scheduled_task_starts_at(%Date{} = date),
    do: NaiveDateTime.new!(date, Time.new!(@roadmap_default_task_hour, 0, 0))

  defp roadmap_duration_label(starts_at, nil) when is_struct(starts_at, NaiveDateTime),
    do: "Point in time"

  defp roadmap_duration_label(starts_at, ends_at)
       when is_struct(starts_at, NaiveDateTime) and is_struct(ends_at, NaiveDateTime) do
    case NaiveDateTime.diff(ends_at, starts_at, :second) do
      diff when diff <= 0 -> "Point in time"
      diff -> humanize_roadmap_seconds(diff) <> " span"
    end
  end

  defp roadmap_time_label(starts_at, nil),
    do: Calendar.strftime(starts_at, "%I:%M %p")

  defp roadmap_time_label(starts_at, ends_at) do
    Calendar.strftime(starts_at, "%I:%M %p") <>
      " - " <> Calendar.strftime(ends_at, "%I:%M %p")
  end

  defp roadmap_canvas_class(rows, expanded_item_ids, editing_timeline_entry_id)
       when is_list(rows) do
    case roadmap_focus_mode(rows, expanded_item_ids, editing_timeline_entry_id) do
      :none ->
        "mt-6 overflow-hidden rounded-2xl border border-[color:var(--hub-border)] bg-[var(--hub-surface)] pb-14"

      :view ->
        "mt-6 overflow-hidden rounded-2xl border border-[color:var(--hub-border)] bg-[var(--hub-surface)] pb-16"

      :edit ->
        "mt-6 overflow-hidden rounded-2xl border border-[color:var(--hub-border)] bg-[var(--hub-surface)] pb-20"
    end
  end

  defp roadmap_canvas_focused?(rows, expanded_item_ids, editing_timeline_entry_id) do
    roadmap_focus_mode(rows, expanded_item_ids, editing_timeline_entry_id) != :none
  end

  defp roadmap_backdrop_class(rows, expanded_item_ids, editing_timeline_entry_id) do
    case roadmap_focus_mode(rows, expanded_item_ids, editing_timeline_entry_id) do
      :edit ->
        "pointer-events-none absolute inset-0 z-10 bg-black/30 backdrop-blur-[2.5px] transition duration-300 ease-out"

      :view ->
        "pointer-events-none absolute inset-0 z-10 bg-black/20 backdrop-blur-[1.5px] transition duration-300 ease-out"

      :none ->
        "hidden"
    end
  end

  defp roadmap_focus_mode(rows, expanded_item_ids, editing_timeline_entry_id) do
    cond do
      present?(editing_timeline_entry_id) ->
        :edit

      Enum.any?(rows, &roadmap_row_expanded?(&1, expanded_item_ids)) ->
        :view

      true ->
        :none
    end
  end

  defp roadmap_row_expanded?(row, expanded_item_ids) do
    Enum.any?(row.items, &(&1.id in expanded_item_ids))
  end

  defp roadmap_row_class(row, expanded_item_ids, editing_timeline_entry_id, focus_mode) do
    editing_row? = Enum.any?(row.items, &(&1.record_id == editing_timeline_entry_id))
    expanded_row? = roadmap_row_expanded?(row, expanded_item_ids)

    base =
      "relative rounded-2xl border border-[color:var(--hub-border)] bg-[linear-gradient(180deg,rgba(255,255,255,0.045),rgba(139,92,246,0.06))] px-2 py-3 transition duration-300 ease-out"

    cond do
      editing_row? ->
        base <>
          " z-20 border-[color:var(--hub-border)] bg-[linear-gradient(180deg,rgba(255,255,255,0.045),rgba(139,92,246,0.06))] shadow-[0_28px_70px_-42px_rgba(109,40,217,0.65)] ring-1 ring-[color:var(--hub-accent)]/30"

      focus_mode == :view and expanded_row? ->
        base <>
          " z-20 border-[color:var(--hub-border)] bg-[linear-gradient(180deg,rgba(255,255,255,0.045),rgba(139,92,246,0.06))] shadow-[0_24px_56px_-38px_rgba(109,40,217,0.4)] ring-1 ring-[color:var(--hub-accent)]/30"

      focus_mode != :none ->
        base <> " opacity-85"

      true ->
        base
    end
  end

  defp roadmap_row_style(row, expanded_item_ids, editing_timeline_entry_id) do
    height_rem =
      Enum.reduce(row.items, row.height_rem, fn item, acc ->
        bottom_rem =
          item.lane_index * 5.5 +
            0.75 +
            roadmap_lane_height(
              item.id in expanded_item_ids,
              item.record_id == editing_timeline_entry_id
            ) +
            0.75

        max(acc, bottom_rem)
      end)

    "height: #{Float.round(height_rem, 2)}rem;"
  end

  defp roadmap_item_lane_style(item, expanded?, editing?) do
    top_rem = item.lane_index * 5.5 + 0.75
    height_rem = roadmap_lane_height(expanded?, editing?)

    "top: #{Float.round(top_rem, 2)}rem; height: #{height_rem}rem;"
  end

  defp roadmap_lane_height(false, _editing?), do: 1.5
  defp roadmap_lane_height(true, false), do: 11.5
  defp roadmap_lane_height(true, true), do: 28.5

  defp roadmap_duration_visible?(item) do
    roadmap_duration_percent(item) > 0
  end

  defp roadmap_duration_style(item) do
    left_percent = roadmap_start_percent(item)
    width_percent = roadmap_duration_percent(item)

    "left: #{Float.round(left_percent, 2)}%; width: #{Float.round(width_percent, 2)}%; top: 0.62rem;"
  end

  defp roadmap_duration_class(%{item_type: :task, status: "release"}),
    do: "absolute h-1.5 rounded-full bg-[color:var(--tone-income)]/45"

  defp roadmap_duration_class(%{item_type: :task, status: "qa"}),
    do: "absolute h-1.5 rounded-full bg-[color:var(--tone-review)]/45"

  defp roadmap_duration_class(%{item_type: :task, status: "wip"}),
    do: "absolute h-1.5 rounded-full bg-[color:var(--tone-info)]/45"

  defp roadmap_duration_class(%{item_type: :task}),
    do: "absolute h-1.5 rounded-full bg-[color:var(--hub-accent)]/40"

  defp roadmap_duration_class(%{kind: "release"}),
    do: "absolute h-1.5 rounded-full bg-[color:var(--tone-income)]/45"

  defp roadmap_duration_class(%{kind: "deadline"}),
    do: "absolute h-1.5 rounded-full bg-[color:var(--tone-expense)]/45"

  defp roadmap_duration_class(%{kind: "note"}),
    do: "absolute h-1.5 rounded-full bg-[color:var(--tone-info)]/45"

  defp roadmap_duration_class(_item),
    do: "absolute h-1.5 rounded-full bg-[color:var(--hub-accent)]/40"

  defp roadmap_preview_anchor_style(item) do
    "left: calc(#{Float.round(roadmap_start_percent(item), 2)}% - 0.5rem); top: 0.18rem; width: 1rem; height: 1rem;"
  end

  defp roadmap_dot_class(item, true, true) do
    roadmap_dot_base(item) <>
      " z-30 scale-110 ring-4 ring-[color:var(--hub-accent)]/30 shadow-[0_0_0_10px_rgba(139,92,246,0.35)] animate-pulse"
  end

  defp roadmap_dot_class(item, true, false) do
    roadmap_dot_base(item) <>
      " z-30 scale-110 ring-4 ring-[color:var(--hub-accent)]/30 shadow-[0_0_0_10px_rgba(196,181,253,0.48)] animate-[pulse_700ms_ease-out]"
  end

  defp roadmap_dot_class(item, false, false) do
    roadmap_dot_base(item) <>
      " group-hover/roadmap:z-30 group-hover/roadmap:scale-110 group-hover/roadmap:ring-4 group-hover/roadmap:ring-[color:var(--hub-accent)]/30 group-hover/roadmap:shadow-[0_0_0_10px_rgba(196,181,253,0.42)] group-focus-within/roadmap:z-30 group-focus-within/roadmap:scale-110 group-focus-within/roadmap:ring-4 group-focus-within/roadmap:ring-[color:var(--hub-accent)]/30 group-focus-within/roadmap:shadow-[0_0_0_10px_rgba(196,181,253,0.42)]"
  end

  defp roadmap_dot_class(item, false, true) do
    roadmap_dot_base(item) <>
      " z-30 ring-4 ring-[color:var(--hub-accent)]/30 shadow-[0_0_0_10px_rgba(139,92,246,0.35)] animate-pulse"
  end

  defp roadmap_dot_base(item) do
    "absolute inset-0 inline-flex rounded-full border-4 border-[color:var(--hub-bg)] shadow-[0_0_0_1px_rgba(196,181,253,0.55)] transition duration-300 " <>
      roadmap_dot_tone(item)
  end

  defp roadmap_dot_tone(%{item_type: :task, status: "release"}), do: "bg-[var(--tone-income)]"
  defp roadmap_dot_tone(%{item_type: :task, status: "qa"}), do: "bg-[var(--tone-review)]"
  defp roadmap_dot_tone(%{item_type: :task, status: "wip"}), do: "bg-[var(--tone-info)]"
  defp roadmap_dot_tone(%{item_type: :task}), do: "bg-[var(--hub-accent)]"
  defp roadmap_dot_tone(%{kind: "release"}), do: "bg-[var(--tone-income)]"
  defp roadmap_dot_tone(%{kind: "deadline"}), do: "bg-[var(--tone-expense)]"
  defp roadmap_dot_tone(%{kind: "note"}), do: "bg-[var(--tone-info)]"
  defp roadmap_dot_tone(_item), do: "bg-[var(--hub-accent)]"

  defp roadmap_popover_class(true, true) do
    "fx-preview absolute z-30 max-h-[36rem] translate-y-0 scale-100 overflow-hidden rounded-[1.35rem] opacity-100 pointer-events-auto shadow-[0_34px_90px_-34px_rgba(109,40,217,0.72)] ring-2 ring-[color:var(--hub-accent)]/30 backdrop-blur-sm transition-all duration-300 ease-out"
  end

  defp roadmap_popover_class(true, false) do
    "fx-preview absolute z-20 max-h-[18rem] translate-y-0 scale-100 overflow-hidden rounded-[1.2rem] opacity-100 pointer-events-auto shadow-[0_26px_64px_-28px_rgba(0,0,0,0.7)] ring-1 ring-[color:var(--hub-border)] backdrop-blur-sm transition-all duration-200 ease-out"
  end

  defp roadmap_popover_class(false, false) do
    "fx-preview absolute z-20 max-h-[18rem] translate-y-0 scale-100 overflow-hidden rounded-2xl opacity-100 pointer-events-auto shadow-[0_18px_42px_-28px_rgba(109,40,217,0.4)] ring-1 ring-[color:var(--hub-border)] backdrop-blur-sm transition-all duration-300 ease-out"
  end

  defp roadmap_preview_class do
    "fx-preview pointer-events-none absolute z-20 hidden md:block"
  end

  defp roadmap_popover_transition(true) do
    JS.transition(
      {"transition-all duration-250 ease-out", "opacity-0 translate-y-2 scale-[0.97]",
       "opacity-100 translate-y-0 scale-100"}
    )
  end

  defp roadmap_popover_transition(false) do
    JS.transition(
      {"transition-all duration-180 ease-out", "opacity-0 translate-y-1 scale-[0.98]",
       "opacity-100 translate-y-0 scale-100"}
    )
  end

  defp roadmap_popover_click_away(true), do: nil
  defp roadmap_popover_click_away(false), do: "close_roadmap_items"

  defp roadmap_preview_style(item) do
    start_percent = roadmap_start_percent(item)
    width_style = "width: min(16.5rem, calc(100vw - 4rem));"
    offset_style = "top: 1.55rem;"

    if start_percent > 68 do
      "right: 0; #{offset_style} #{width_style}"
    else
      "left: 0; #{offset_style} #{width_style}"
    end
  end

  defp roadmap_popover_style(item, editing?) do
    start_percent = roadmap_start_percent(item)
    width_rem = if editing?, do: 24.0, else: 22.0
    width_style = "width: min(#{width_rem}rem, calc(100% - 1rem));"
    top_style = "top: 1.65rem;"
    max_left_rem = Float.round(width_rem + 0.5, 1)

    if start_percent > 64 do
      "right: 0.5rem; #{top_style} #{width_style}"
    else
      "left: clamp(0.5rem, #{Float.round(start_percent, 2)}%, calc(100% - #{max_left_rem}rem)); #{top_style} #{width_style}"
    end
  end

  defp roadmap_start_percent(item) do
    clamp_to_roadmap_window(minutes_since_midnight(item.starts_at)) /
      roadmap_window_minutes() * 100
  end

  defp roadmap_duration_percent(item) do
    start_minutes = clamp_to_roadmap_window(minutes_since_midnight(item.starts_at))
    end_minutes = clamp_to_roadmap_window(roadmap_end_minutes(item.starts_at, item.ends_at))

    case end_minutes - start_minutes do
      diff when diff <= 0 -> 0
      diff -> max(diff / roadmap_window_minutes() * 100, 1.1)
    end
  end

  defp roadmap_end_minutes(starts_at, nil) do
    minutes_since_midnight(starts_at)
  end

  defp roadmap_end_minutes(_starts_at, ends_at), do: minutes_since_midnight(ends_at)

  defp minutes_since_midnight(datetime) do
    datetime.hour * 60 + datetime.minute - @roadmap_start_hour * 60
  end

  defp clamp_to_roadmap_window(minutes) do
    min(max(minutes, 0), roadmap_window_minutes())
  end

  defp roadmap_window_minutes, do: (@roadmap_end_hour - @roadmap_start_hour) * 60

  defp format_hour_label(hour) do
    suffix = if hour < 12, do: "AM", else: "PM"
    normalized_hour = rem(hour - 1, 12) + 1
    "#{normalized_hour}#{suffix}"
  end

  defp humanize_roadmap_seconds(seconds) when seconds >= 86_400 do
    "#{div(seconds, 86_400)}d"
  end

  defp humanize_roadmap_seconds(seconds) when seconds >= 3600 do
    "#{div(seconds, 3600)}h"
  end

  defp humanize_roadmap_seconds(seconds) do
    minutes = max(div(seconds, 60), 1)
    "#{minutes}m"
  end

  defp toggle_item(expanded_item_ids, id) do
    if id in expanded_item_ids do
      Enum.reject(expanded_item_ids, &(&1 == id))
    else
      [id | expanded_item_ids]
    end
  end

  defp prune_expanded_items(expanded_item_ids, canvas, roadmap_rows) do
    valid_ids =
      Enum.map(canvas.milestones, & &1.id) ++
        Enum.flat_map(roadmap_rows, fn row -> Enum.map(row.items, & &1.id) end) ++
        Enum.flat_map(canvas.stage_items, fn {_stage, items} -> Enum.map(items, & &1.id) end)

    Enum.filter(expanded_item_ids, &(&1 in valid_ids))
  end

  defp normalize_entry_kind("milestone"), do: "milestone"
  defp normalize_entry_kind(_kind), do: "task"

  defp office_project_path(project), do: ~p"/office/#{project.slug}"

  defp project_action_shell_class(true) do
    "w-full max-w-md"
  end

  defp project_action_shell_class(false) do
    "w-[10.5rem] sm:w-[10.75rem]"
  end

  defp current_project_default?(nil, _default_project_id), do: false
  defp current_project_default?(_project, nil), do: false

  defp current_project_default?(project, default_project_id) do
    project.id == default_project_id
  end

  defp project_link_class(project, current_project) do
    base =
      "inline-flex items-center rounded-full border px-3 py-1.5 text-sm font-semibold transition duration-300"

    if current_project && current_project.id == project.id do
      base <>
        " border-[color:var(--hub-accent)]/50 bg-[color:var(--hub-accent)]/12 text-[var(--hub-accent-2)] shadow-sm"
    else
      base <>
        " border-[color:var(--hub-border)] bg-[var(--hub-surface)] text-[var(--hub-muted)] hover:border-[color:var(--hub-border)] hover:text-[var(--hub-text)]"
    end
  end

  defp entry_kind_class(kind, selected_kind) do
    base =
      "inline-flex items-center rounded-full border px-3 py-1.5 text-sm font-semibold transition duration-300"

    if kind == selected_kind do
      base <>
        " border-[color:var(--hub-accent)]/50 bg-[color:var(--hub-accent)]/12 text-[var(--hub-accent-2)]"
    else
      base <>
        " border-[color:var(--hub-border)] bg-[var(--hub-surface)] text-[var(--hub-muted)] hover:border-[color:var(--hub-border)] hover:text-[var(--hub-text)]"
    end
  end

  defp entry_title_placeholder("milestone"), do: "Public beta milestone"
  defp entry_title_placeholder(_kind), do: "Ship Office canvas review"

  defp entry_description_placeholder("milestone"),
    do: "Explain the milestone, release note, or deadline context."

  defp entry_description_placeholder(_kind),
    do: "Add scope, expected outcome, or dependency notes."

  defp entry_submit_label("milestone"), do: "Add milestone"
  defp entry_submit_label(_kind), do: "Add task"

  defp milestone_kind_selected?(nil, "milestone"), do: true
  defp milestone_kind_selected?(selected_kind, value), do: selected_kind == value

  defp stage_canvas_style([], _expanded_item_ids), do: "min-height: 18rem;"

  defp stage_canvas_style(items, expanded_item_ids) do
    "height: #{Float.round(stage_canvas_height_rem(items, expanded_item_ids), 2)}rem;"
  end

  defp stage_item_position_style(item, expanded?) do
    "top: #{Float.round(stage_item_top(item), 2)}rem; height: #{stage_item_height(expanded?)}rem;"
  end

  defp stage_item_container_class(true) do
    "absolute inset-x-4 z-40"
  end

  defp stage_item_container_class(false) do
    "absolute inset-x-4 z-0 transition-[z-index] duration-150 hover:z-30"
  end

  defp stage_canvas_height_rem(items, expanded_item_ids) do
    Enum.reduce(items, 18.0, fn item, acc ->
      bottom_rem =
        stage_item_top(item) +
          stage_item_height(expanded?(expanded_item_ids, item.id)) +
          1.25

      max(acc, bottom_rem)
    end)
  end

  defp stage_item_top(item), do: item.slot_index * 4.75 + 1.0

  defp stage_item_height(false), do: 1.4
  defp stage_item_height(true), do: 10.75

  defp stage_dot_class("queue", expanded?),
    do: stage_dot_base("bg-[var(--hub-accent)]", expanded?)

  defp stage_dot_class("wip", expanded?), do: stage_dot_base("bg-[var(--tone-info)]", expanded?)
  defp stage_dot_class("qa", expanded?), do: stage_dot_base("bg-[var(--tone-review)]", expanded?)

  defp stage_dot_class("release", expanded?),
    do: stage_dot_base("bg-[var(--tone-income)]", expanded?)

  defp stage_dot_class(_stage, expanded?), do: stage_dot_base("bg-[var(--hub-muted)]", expanded?)

  defp stage_dot_base(color_class, true) do
    "absolute left-0 top-1 inline-flex h-4 w-4 rounded-full border-4 border-[color:var(--hub-bg)] shadow-[0_0_0_1px_rgba(196,181,253,0.55)] transition duration-300 " <>
      color_class <>
      " z-20 scale-110 ring-4 ring-[color:var(--hub-accent)]/30 shadow-[0_0_0_10px_rgba(196,181,253,0.48)]"
  end

  defp stage_dot_base(color_class, false) do
    "absolute left-0 top-1 inline-flex h-4 w-4 rounded-full border-4 border-[color:var(--hub-bg)] shadow-[0_0_0_1px_rgba(196,181,253,0.55)] transition duration-300 " <>
      color_class <>
      " pointer-events-none group-hover/stage:z-20 group-hover/stage:scale-110 group-hover/stage:ring-4 group-hover/stage:ring-[color:var(--hub-accent)]/30 group-hover/stage:shadow-[0_0_0_10px_rgba(196,181,253,0.42)]"
  end

  defp stage_title_rail_class(true) do
    "absolute left-6 right-0 top-0.5 truncate text-sm font-medium text-[var(--hub-text)] transition duration-200"
  end

  defp stage_title_rail_class(false) do
    "absolute left-6 right-0 top-0.5 truncate text-sm font-medium text-[var(--hub-muted)] transition duration-200 group-hover/stage:text-[var(--hub-text)]"
  end

  defp stage_preview_class do
    "stage-fx-preview fx-preview absolute z-50 hidden md:block"
  end

  defp stage_preview_style(stage) do
    width_style = "width: min(18rem, calc(100vw - 5rem));"
    top_style = "top: -0.35rem;"

    if stage in ["qa", "release"] do
      "right: 1.65rem; #{top_style} #{width_style}"
    else
      "left: 1.65rem; #{top_style} #{width_style}"
    end
  end

  defp stage_popover_class do
    "fx-preview absolute z-[60] max-h-[18rem] translate-y-0 scale-100 overflow-hidden rounded-[1.2rem] opacity-100 pointer-events-auto shadow-[0_26px_64px_-28px_rgba(0,0,0,0.7)] ring-1 ring-[color:var(--hub-border)] backdrop-blur-sm transition-all duration-200 ease-out"
  end

  defp stage_popover_style(stage) do
    width_style = "width: min(19rem, calc(100vw - 5rem));"
    top_style = "top: -0.35rem;"

    if stage in ["qa", "release"] do
      "right: 1.65rem; #{top_style} #{width_style}"
    else
      "left: 1.65rem; #{top_style} #{width_style}"
    end
  end

  defp stage_popover_transition do
    JS.transition(
      {"transition-all duration-180 ease-out", "opacity-0 translate-y-1 scale-[0.98]",
       "opacity-100 translate-y-0 scale-100"}
    )
  end

  defp stage_focus_backdrop_class(true) do
    "pointer-events-none absolute z-30 rounded-[1.6rem] bg-[var(--hub-surface)] opacity-100 backdrop-blur-[3px] transition duration-200 ease-out"
  end

  defp stage_focus_backdrop_class(false) do
    "pointer-events-none absolute z-30 rounded-[1.6rem] bg-[var(--hub-surface)] opacity-0 backdrop-blur-[2.5px] transition duration-200 ease-out group-hover/stage:opacity-100"
  end

  defp stage_focus_backdrop_style(item, items, expanded_item_ids) do
    lane_height = stage_canvas_height_rem(items, expanded_item_ids)
    top_offset = stage_item_top(item) + 1.0

    "left: -1rem; top: -#{Float.round(top_offset, 2)}rem; width: calc(100% + 2rem); height: #{Float.round(lane_height, 2)}rem;"
  end

  defp stage_has_expanded_item?(items, expanded_item_ids) do
    Enum.any?(items, &expanded?(expanded_item_ids, &1.id))
  end

  defp stage_item_ids(stage_items) do
    Enum.flat_map(stage_items, fn {_stage, items} -> Enum.map(items, & &1.id) end)
  end

  defp priority_badge_class("high") do
    "inline-flex items-center rounded-full border border-[color:var(--tone-expense)]/35 bg-[color:var(--tone-expense)]/12 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-[var(--tone-expense)]"
  end

  defp priority_badge_class("medium") do
    "inline-flex items-center rounded-full border border-[color:var(--tone-review)]/35 bg-[color:var(--tone-review)]/12 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-[var(--tone-review)]"
  end

  defp priority_badge_class(_priority) do
    "inline-flex items-center rounded-full border border-[color:var(--tone-income)]/35 bg-[color:var(--tone-income)]/12 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-[var(--tone-income)]"
  end

  defp transition_actions("queue") do
    [%{label: "Start", to: "wip", button_class: "btn btn-primary btn-xs"}]
  end

  defp transition_actions("wip") do
    [%{label: "Send to QA", to: "qa", button_class: "btn btn-secondary btn-xs"}]
  end

  defp transition_actions("qa") do
    [
      %{label: "Return to WIP", to: "wip", button_class: "btn btn-ghost btn-xs"},
      %{label: "Approve for Release", to: "release", button_class: "btn btn-primary btn-xs"}
    ]
  end

  defp transition_actions(_status), do: []

  defp lane_title("queue"), do: "Queue"
  defp lane_title("wip"), do: "WIP"
  defp lane_title("qa"), do: "QA"
  defp lane_title("release"), do: "Release"
  defp lane_title(_stage), do: "Stage"

  defp lane_message("wip"), do: "Task moved to WIP"
  defp lane_message("qa"), do: "Task sent to QA"
  defp lane_message("release"), do: "Task approved for Release"
  defp lane_message(_status), do: "Task updated"

  defp timeline_kind_label("milestone"), do: "Milestone"
  defp timeline_kind_label("deadline"), do: "Deadline"
  defp timeline_kind_label("release"), do: "Release"
  defp timeline_kind_label("note"), do: "Note"
  defp timeline_kind_label(_kind), do: "Roadmap"

  defp roadmap_badge_label(%{item_type: :task, status: status}), do: lane_title(status) <> " task"
  defp roadmap_badge_label(%{kind: kind}), do: timeline_kind_label(kind)

  defp datetime_local_value(nil), do: nil

  defp datetime_local_value(%NaiveDateTime{} = value),
    do: Calendar.strftime(value, "%Y-%m-%dT%H:%M")

  defp datetime_local_value(value) when is_binary(value), do: value

  defp expanded?(expanded_item_ids, id), do: id in expanded_item_ids

  defp present?(value), do: is_binary(value) and String.trim(value) != ""

  defp translate_error({message, opts}) do
    Enum.reduce(opts, message, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end
end
