defmodule CoreWeb.OfficeLive do
  use CoreWeb, :live_view

  alias Core.Office

  @default_entry_kind "task"
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
       current_project: nil,
       projects: [],
       project_form_open: false,
       entry_form_open: false,
       entry_kind: @default_entry_kind,
       expanded_item_ids: [],
       page_title: "IziOffice"
     )
     |> assign_project_form()
     |> assign_entry_form()}
  end

  def handle_params(params, _uri, socket) do
    user = socket.assigns.current_scope.user
    current_project = Office.get_project_for_user(user, params["slug"])
    projects = Office.list_projects_for_user(user)

    {:noreply,
     socket
     |> assign(projects: projects, current_project: current_project)
     |> assign_workbench()}
  end

  def handle_event("open_entry_form", _params, socket) do
    {:noreply, assign(socket, entry_form_open: true, project_form_open: false)}
  end

  def handle_event("close_entry_form", _params, socket) do
    {:noreply,
     socket
     |> assign(entry_form_open: false, entry_kind: @default_entry_kind)
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
    {:noreply, assign(socket, project_form_open: true, entry_form_open: false)}
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

  def handle_event("toggle_canvas_item", %{"id" => id}, socket) do
    {:noreply,
     assign(socket, expanded_item_ids: toggle_item(socket.assigns.expanded_item_ids, id))}
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

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="min-h-screen bg-purple-50 text-slate-900">
        <main class="mx-auto max-w-7xl px-6 pb-16 pt-12">
          <section class="mb-8 flex flex-wrap items-end justify-between gap-4">
            <div>
              <p class="text-xs font-semibold uppercase tracking-[0.24em] text-purple-500">Private roadmap canvas</p>
              <h1 class="mt-3 text-4xl font-semibold tracking-tight text-slate-900 sm:text-5xl">
                IziOffice
              </h1>
              <p class="mt-3 max-w-3xl text-sm leading-6 text-slate-600 sm:text-base">
                Projects own the roadmap. Tasks and milestones render directly on the same canvas, so new entries appear without duplication.
              </p>
            </div>

            <div :if={@current_project} class="rounded-2xl border border-purple-100 bg-white/80 px-4 py-3 shadow-sm">
              <p class="text-[11px] font-semibold uppercase tracking-wide text-slate-400">Current project</p>
              <p class="mt-1 text-sm font-semibold text-slate-900"><%= @current_project.name %></p>
              <p class="mt-1 text-xs text-slate-500">
                <%= length(@canvas_milestones) %> milestones and <%= @canvas_item_count %> roadmap cards
              </p>
            </div>
          </section>

          <section class="overflow-hidden rounded-[2rem] border border-purple-100 bg-white/80 shadow-[0_30px_80px_-45px_rgba(109,40,217,0.45)] backdrop-blur">
            <div class="border-b border-purple-100/80 bg-gradient-to-r from-white via-purple-50/80 to-purple-100/60 px-6 py-6">
              <div class="flex flex-col gap-5 xl:flex-row xl:items-end xl:justify-between">
                <div class="flex-1">
                  <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Projects</p>
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
                      class="group inline-flex w-full items-center gap-2 rounded-2xl border border-purple-200 bg-white/90 px-4 py-3 text-sm font-semibold text-slate-700 shadow-sm transition-all duration-300 ease-out hover:-translate-y-0.5 hover:scale-[1.01] hover:border-purple-300 hover:shadow-md active:translate-y-0 active:scale-[0.99]"
                    >
                      <span class="inline-flex h-7 w-7 items-center justify-center rounded-full bg-slate-100 text-base leading-none text-slate-600 transition-transform duration-300 ease-out group-hover:rotate-90">
                        +
                      </span>
                      New project
                    </button>

                    <.form
                      :if={@project_form_open}
                      for={@project_form}
                      phx-submit="create_project"
                      class="absolute right-0 top-0 z-20 w-[min(28rem,calc(100vw-3rem))] rounded-2xl border border-purple-200 bg-white/95 p-2.5 shadow-[0_18px_36px_-28px_rgba(109,40,217,0.45)] transition-all duration-300 ease-out"
                    >
                      <div class="flex flex-col gap-2 sm:flex-row sm:items-center">
                        <div class="min-w-0 flex-1">
                          <input
                            id="project-name"
                            name={@project_form[:name].name}
                            value={@project_form[:name].value}
                            type="text"
                            placeholder="Project title"
                            class="w-full rounded-xl border border-purple-100 bg-white px-4 py-3 text-sm text-slate-900 outline-none transition-all duration-200 focus:border-purple-300 focus:ring-2 focus:ring-purple-200"
                          />
                          <p :for={error <- @project_form[:name].errors} class="mt-1 text-xs text-rose-600">
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

                  <button
                    :if={!@entry_form_open}
                    type="button"
                    phx-click="open_entry_form"
                    class="group inline-flex items-center gap-2 rounded-2xl border border-purple-200 bg-white/90 px-4 py-3 text-sm font-semibold text-purple-700 shadow-sm transition-all duration-300 ease-out hover:-translate-y-0.5 hover:scale-[1.01] hover:border-purple-300 hover:shadow-md active:translate-y-0 active:scale-[0.99]"
                  >
                    <span class="inline-flex h-7 w-7 items-center justify-center rounded-full bg-purple-100 text-base leading-none text-purple-600 transition-transform duration-300 ease-out group-hover:rotate-90">
                      +
                    </span>
                    Add entry
                  </button>
                </div>
              </div>

              <div :if={@entry_form_open} class="mt-5 flex justify-end">
                <.form
                  for={@entry_form}
                  phx-submit="create_entry"
                  class="w-full max-w-xl rounded-[1.5rem] border border-purple-100 bg-white/92 p-4 shadow-[0_24px_60px_-38px_rgba(109,40,217,0.48)] backdrop-blur-sm transition-all duration-300 ease-out"
                >
                  <div class="flex items-center justify-between gap-4">
                    <div>
                      <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Add roadmap entry</p>
                    </div>
                    <button
                      type="button"
                      phx-click="close_entry_form"
                      class="inline-flex h-9 w-9 items-center justify-center rounded-full border border-purple-100 bg-white text-slate-500 transition hover:border-purple-200 hover:text-slate-700"
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
                      <label for="entry-title" class="mb-1 block text-[11px] font-semibold uppercase tracking-wide text-slate-500">
                        Title
                      </label>
                      <input
                        id="entry-title"
                        name={@entry_form[:title].name}
                        value={@entry_form[:title].value}
                        type="text"
                        placeholder={entry_title_placeholder(@entry_kind)}
                        class="w-full rounded-xl border border-purple-100 bg-white px-4 py-3 text-sm text-slate-900 outline-none transition focus:border-purple-300 focus:ring-2 focus:ring-purple-200"
                      />
                      <p :for={error <- @entry_form[:title].errors} class="mt-1 text-xs text-rose-600">
                        <%= translate_error(error) %>
                      </p>
                    </div>

                    <div>
                      <label for="entry-description" class="mb-1 block text-[11px] font-semibold uppercase tracking-wide text-slate-500">
                        Description
                      </label>
                      <textarea
                        id="entry-description"
                        name={@entry_form[:description].name}
                        class="h-20 w-full rounded-xl border border-purple-100 bg-white px-4 py-3 text-sm text-slate-900 outline-none transition focus:border-purple-300 focus:ring-2 focus:ring-purple-200"
                        placeholder={entry_description_placeholder(@entry_kind)}
                      ><%= @entry_form[:description].value %></textarea>
                    </div>

                    <div :if={@entry_kind == "task"} class="grid gap-3 sm:grid-cols-3">
                      <div>
                        <label for="entry-priority" class="mb-1 block text-[11px] font-semibold uppercase tracking-wide text-slate-500">
                          Priority
                        </label>
                        <select
                          id="entry-priority"
                          name={@entry_form[:priority].name}
                          class="w-full rounded-xl border border-purple-100 bg-white px-4 py-3 text-sm text-slate-900 outline-none transition focus:border-purple-300 focus:ring-2 focus:ring-purple-200"
                        >
                          <option value="low" selected={@entry_form[:priority].value == "low"}>Low</option>
                          <option value="medium" selected={@entry_form[:priority].value in [nil, "medium"]}>Medium</option>
                          <option value="high" selected={@entry_form[:priority].value == "high"}>High</option>
                        </select>
                      </div>

                      <div>
                        <label for="entry-scheduled-for" class="mb-1 block text-[11px] font-semibold uppercase tracking-wide text-slate-500">
                          Scheduled
                        </label>
                        <input
                          id="entry-scheduled-for"
                          name={@entry_form[:scheduled_for].name}
                          value={@entry_form[:scheduled_for].value}
                          type="date"
                          class="w-full rounded-xl border border-purple-100 bg-white px-4 py-3 text-sm text-slate-900 outline-none transition focus:border-purple-300 focus:ring-2 focus:ring-purple-200"
                        />
                      </div>

                      <div>
                        <label for="entry-due-at" class="mb-1 block text-[11px] font-semibold uppercase tracking-wide text-slate-500">
                          Due at
                        </label>
                        <input
                          id="entry-due-at"
                          name={@entry_form[:due_at].name}
                          value={datetime_local_value(@entry_form[:due_at].value)}
                          type="datetime-local"
                          class="w-full rounded-xl border border-purple-100 bg-white px-4 py-3 text-sm text-slate-900 outline-none transition focus:border-purple-300 focus:ring-2 focus:ring-purple-200"
                        />
                        <p :for={error <- @entry_form[:due_at].errors} class="mt-1 text-xs text-rose-600">
                          <%= translate_error(error) %>
                        </p>
                      </div>
                    </div>

                    <div :if={@entry_kind == "milestone"} class="grid gap-3 sm:grid-cols-3">
                      <div>
                        <label for="entry-kind" class="mb-1 block text-[11px] font-semibold uppercase tracking-wide text-slate-500">
                          Kind
                        </label>
                        <select
                          id="entry-kind"
                          name={@entry_form[:kind].name}
                          class="w-full rounded-xl border border-purple-100 bg-white px-4 py-3 text-sm text-slate-900 outline-none transition focus:border-purple-300 focus:ring-2 focus:ring-purple-200"
                        >
                          <option :for={{label, value} <- @milestone_kinds} value={value} selected={milestone_kind_selected?(@entry_form[:kind].value, value)}>
                            <%= label %>
                          </option>
                        </select>
                      </div>

                      <div>
                        <label for="entry-starts-at" class="mb-1 block text-[11px] font-semibold uppercase tracking-wide text-slate-500">
                          Starts at
                        </label>
                        <input
                          id="entry-starts-at"
                          name={@entry_form[:starts_at].name}
                          value={datetime_local_value(@entry_form[:starts_at].value)}
                          type="datetime-local"
                          class="w-full rounded-xl border border-purple-100 bg-white px-4 py-3 text-sm text-slate-900 outline-none transition focus:border-purple-300 focus:ring-2 focus:ring-purple-200"
                        />
                        <p :for={error <- @entry_form[:starts_at].errors} class="mt-1 text-xs text-rose-600">
                          <%= translate_error(error) %>
                        </p>
                      </div>

                      <div>
                        <label for="entry-ends-at" class="mb-1 block text-[11px] font-semibold uppercase tracking-wide text-slate-500">
                          Ends at
                        </label>
                        <input
                          id="entry-ends-at"
                          name={@entry_form[:ends_at].name}
                          value={datetime_local_value(@entry_form[:ends_at].value)}
                          type="datetime-local"
                          class="w-full rounded-xl border border-purple-100 bg-white px-4 py-3 text-sm text-slate-900 outline-none transition focus:border-purple-300 focus:ring-2 focus:ring-purple-200"
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
              <div class="rounded-[1.75rem] border border-purple-100 bg-[linear-gradient(180deg,rgba(255,255,255,0.96),rgba(245,243,255,0.8))] p-5 shadow-sm">
                <div class="flex flex-wrap items-end justify-between gap-4">
                  <div>
                    <p class="text-xs font-semibold uppercase tracking-wide text-purple-500">Milestone track</p>
                    <h2 class="mt-1 text-xl font-semibold text-slate-900">Project roadmap</h2>
                  </div>
                  <p class="text-sm text-slate-500">Milestones live above the execution lanes and share the same project context.</p>
                </div>

                <div class="relative mt-6 min-h-[14rem] overflow-hidden rounded-2xl border border-purple-100 bg-white/85 px-5 py-4">
                  <div class="absolute left-10 right-10 top-1/2 h-px bg-purple-100"></div>

                  <%= if @canvas_milestones == [] do %>
                    <div class="flex min-h-[10rem] items-center justify-center rounded-xl border border-dashed border-purple-100 bg-purple-50/40 text-sm text-slate-500">
                      Add a milestone or release note to place a dot on the roadmap track.
                    </div>
                  <% else %>
                    <div
                      :for={item <- @canvas_milestones}
                      class="absolute w-[min(18rem,calc(100%-2rem))] max-w-[18rem]"
                      style={milestone_position_style(item, length(@canvas_milestones))}
                    >
                      <div class="flex items-start gap-3">
                        <button
                          type="button"
                          phx-click="toggle_canvas_item"
                          phx-value-id={item.id}
                          class={milestone_dot_class(item.kind, expanded?(@expanded_item_ids, item.id))}
                          aria-label={"Toggle #{item.title}"}
                        >
                        </button>

                        <article class={milestone_card_class(expanded?(@expanded_item_ids, item.id))}>
                          <button
                            type="button"
                            phx-click="toggle_canvas_item"
                            phx-value-id={item.id}
                            class="w-full text-left"
                          >
                            <div class="flex items-start justify-between gap-3">
                              <div>
                                <p class="text-sm font-semibold text-slate-900"><%= item.title %></p>
                                <p class="mt-1 text-[11px] font-semibold uppercase tracking-wide text-purple-500">
                                  <%= timeline_kind_label(item.kind) %>
                                </p>
                              </div>
                              <span class="rounded-full border border-purple-200 bg-purple-50 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-purple-700">
                                <%= Calendar.strftime(item.starts_at, "%b %d") %>
                              </span>
                            </div>
                          </button>

                          <div :if={expanded?(@expanded_item_ids, item.id)} class="mt-3 space-y-2 text-sm text-slate-600">
                            <p :if={present?(item.description)}><%= item.description %></p>
                            <p class="text-xs text-slate-500">
                              Starts <%= Calendar.strftime(item.starts_at, "%b %d, %Y %I:%M %p") %>
                            </p>
                            <p :if={item.ends_at} class="text-xs text-slate-500">
                              Ends <%= Calendar.strftime(item.ends_at, "%b %d, %Y %I:%M %p") %>
                            </p>
                          </div>
                        </article>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>

              <div class="mt-6 grid gap-4 xl:grid-cols-4">
                <section
                  :for={stage <- @canvas_stages}
                  class="rounded-[1.75rem] border border-purple-100 bg-[linear-gradient(180deg,rgba(255,255,255,0.96),rgba(245,243,255,0.7))] p-4 shadow-sm"
                >
                  <div class="flex items-center justify-between gap-3">
                    <div>
                      <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Stage</p>
                      <h3 class="mt-1 text-lg font-semibold text-slate-900"><%= lane_title(stage) %></h3>
                    </div>
                    <span class="rounded-full border border-purple-200 bg-purple-50 px-2.5 py-1 text-xs font-semibold text-purple-600">
                      <%= length(Map.get(@canvas_stage_items, stage, [])) %>
                    </span>
                  </div>

                  <div class="relative mt-5 rounded-2xl border border-purple-100/80 bg-white/80 px-4 py-4" style={stage_canvas_style(Map.get(@canvas_stage_items, stage, []))}>
                    <div class="absolute bottom-5 left-6 top-5 w-px bg-purple-100"></div>

                    <%= if Map.get(@canvas_stage_items, stage, []) == [] do %>
                      <div class="flex min-h-[14rem] items-center justify-center rounded-xl border border-dashed border-purple-100 bg-purple-50/50 text-sm text-slate-500">
                        No roadmap cards in <%= lane_title(stage) %> yet.
                      </div>
                    <% else %>
                      <div
                        :for={item <- Map.get(@canvas_stage_items, stage, [])}
                        class="absolute inset-x-4"
                        style={stage_item_position_style(item)}
                      >
                        <div class="flex items-start gap-3">
                          <button
                            type="button"
                            phx-click="toggle_canvas_item"
                            phx-value-id={item.id}
                            class={stage_dot_class(stage, expanded?(@expanded_item_ids, item.id))}
                            aria-label={"Toggle #{item.title}"}
                          >
                          </button>

                          <article class={stage_card_class(expanded?(@expanded_item_ids, item.id))}>
                            <button
                              type="button"
                              phx-click="toggle_canvas_item"
                              phx-value-id={item.id}
                              class="w-full text-left"
                            >
                              <div class="flex items-start justify-between gap-3">
                                <div>
                                  <p class="text-sm font-semibold text-slate-900"><%= item.title %></p>
                                  <p class="mt-1 text-[11px] font-semibold uppercase tracking-wide text-purple-500">
                                    <%= String.upcase(item.priority) %> priority
                                  </p>
                                </div>
                                <span class={priority_badge_class(item.priority)}><%= item.sequence %></span>
                              </div>

                              <div class="mt-3 flex flex-wrap gap-2 text-[11px]">
                                <span :if={item.scheduled_for} class="rounded-full border border-sky-200 bg-sky-50 px-2 py-0.5 font-medium text-sky-700">
                                  Scheduled <%= Calendar.strftime(item.scheduled_for, "%b %d") %>
                                </span>
                                <span :if={item.due_at} class="rounded-full border border-amber-200 bg-amber-50 px-2 py-0.5 font-medium text-amber-700">
                                  Due <%= Calendar.strftime(item.due_at, "%b %d %I:%M %p") %>
                                </span>
                              </div>
                            </button>

                            <div :if={expanded?(@expanded_item_ids, item.id)} class="mt-3 space-y-3">
                              <p :if={present?(item.description)} class="text-sm leading-6 text-slate-600"><%= item.description %></p>

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
                          </article>
                        </div>
                      </div>
                    <% end %>
                  </div>
                </section>
              </div>

              <div class="mt-6 grid gap-4 md:grid-cols-2 xl:grid-cols-4">
                <div :for={item <- @agenda_items} class="rounded-2xl border border-purple-100 bg-white/85 p-4 shadow-sm">
                  <p class="text-xs font-semibold uppercase tracking-wide text-slate-400"><%= item.badge %></p>
                  <h3 class="mt-2 text-sm font-semibold text-slate-900"><%= item.title %></h3>
                  <p class="mt-1 text-xs text-slate-500"><%= item.when_label %></p>
                </div>
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
    expanded_item_ids = prune_expanded_items(socket.assigns.expanded_item_ids, canvas)

    assign(socket,
      canvas_stages: Office.canvas_stages(),
      canvas_stage_items: canvas.stage_items,
      canvas_milestones: canvas.milestones,
      canvas_item_count:
        Enum.reduce(canvas.stage_items, 0, fn {_stage, items}, acc -> acc + length(items) end),
      agenda_items: agenda_items(workbench),
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

  defp assign_project_form(socket, attrs \\ %{}) do
    assign(socket, project_form: to_form(Office.project_changeset(attrs), as: :project))
  end

  defp create_task(socket, user, project, params) do
    case Office.create_work_item(user, project, params) do
      {:ok, work_item} ->
        {:noreply,
         socket
         |> put_flash(:info, "Task added to roadmap")
         |> assign(entry_form_open: false, expanded_item_ids: ["work-item:" <> work_item.id])
         |> assign_entry_form()
         |> assign_workbench()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(entry_form_open: true)
         |> assign(entry_kind: "task", entry_form: to_form(changeset, as: :entry))}
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

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(entry_form_open: true)
         |> assign(entry_kind: "milestone", entry_form: to_form(changeset, as: :entry))}
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

  defp toggle_item(expanded_item_ids, id) do
    if id in expanded_item_ids do
      Enum.reject(expanded_item_ids, &(&1 == id))
    else
      [id | expanded_item_ids]
    end
  end

  defp prune_expanded_items(expanded_item_ids, canvas) do
    valid_ids =
      Enum.map(canvas.milestones, & &1.id) ++
        Enum.flat_map(canvas.stage_items, fn {_stage, items} -> Enum.map(items, & &1.id) end)

    Enum.filter(expanded_item_ids, &(&1 in valid_ids))
  end

  defp normalize_entry_kind("milestone"), do: "milestone"
  defp normalize_entry_kind(_kind), do: "task"

  defp office_project_path(project), do: ~p"/office/#{project.slug}"

  defp project_action_shell_class(true) do
    "relative w-[10.5rem] sm:w-[10.75rem]"
  end

  defp project_action_shell_class(false) do
    "relative w-[10.5rem] sm:w-[10.75rem]"
  end

  defp project_link_class(project, current_project) do
    base =
      "inline-flex items-center rounded-full border px-3 py-1.5 text-sm font-semibold transition duration-300"

    if current_project && current_project.id == project.id do
      base <> " border-purple-300 bg-purple-50 text-purple-700 shadow-sm"
    else
      base <>
        " border-purple-100 bg-white/90 text-slate-600 hover:border-purple-200 hover:text-slate-900"
    end
  end

  defp entry_kind_class(kind, selected_kind) do
    base =
      "inline-flex items-center rounded-full border px-3 py-1.5 text-sm font-semibold transition duration-300"

    if kind == selected_kind do
      base <> " border-purple-300 bg-purple-50 text-purple-700"
    else
      base <>
        " border-purple-100 bg-white text-slate-600 hover:border-purple-200 hover:text-slate-900"
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

  defp stage_canvas_style([]), do: "min-height: 18rem;"

  defp stage_canvas_style(items) do
    slot_count = max(length(items), 1)
    "height: #{slot_count * 13 + 8}rem;"
  end

  defp stage_item_position_style(item) do
    "top: #{item.slot_index * 13 + 1}rem;"
  end

  defp milestone_position_style(item, total) do
    left_percent =
      if total <= 1 do
        50.0
      else
        item.slot_index / (total - 1) * 100
      end

    top_rem = 1.0 + item.track_index * 5.4
    "left: calc(#{Float.round(left_percent, 2)}% - 8.5rem); top: #{top_rem}rem;"
  end

  defp stage_dot_class("queue", expanded?), do: dot_class("bg-purple-500", expanded?)
  defp stage_dot_class("wip", expanded?), do: dot_class("bg-sky-500", expanded?)
  defp stage_dot_class("qa", expanded?), do: dot_class("bg-amber-500", expanded?)
  defp stage_dot_class("release", expanded?), do: dot_class("bg-emerald-500", expanded?)
  defp stage_dot_class(_stage, expanded?), do: dot_class("bg-slate-500", expanded?)

  defp milestone_dot_class("release", expanded?), do: dot_class("bg-emerald-500", expanded?)
  defp milestone_dot_class("deadline", expanded?), do: dot_class("bg-rose-500", expanded?)
  defp milestone_dot_class("note", expanded?), do: dot_class("bg-sky-500", expanded?)
  defp milestone_dot_class(_kind, expanded?), do: dot_class("bg-purple-500", expanded?)

  defp dot_class(color_class, expanded?) do
    base =
      "mt-5 inline-flex h-4 w-4 shrink-0 rounded-full border-4 border-white shadow-[0_0_0_1px_rgba(196,181,253,0.55)] transition duration-300"

    scale = if expanded?, do: " scale-110", else: " hover:scale-105"
    base <> " " <> color_class <> scale
  end

  defp stage_card_class(true) do
    "flex-1 rounded-2xl border border-purple-200 bg-white px-4 py-4 shadow-[0_16px_32px_-24px_rgba(109,40,217,0.75)]"
  end

  defp stage_card_class(false) do
    "flex-1 rounded-2xl border border-purple-100 bg-white/95 px-4 py-4 shadow-sm transition duration-300 hover:-translate-y-0.5 hover:shadow-md"
  end

  defp milestone_card_class(true) do
    "flex-1 rounded-2xl border border-purple-200 bg-white px-4 py-4 shadow-[0_16px_32px_-24px_rgba(109,40,217,0.65)]"
  end

  defp milestone_card_class(false) do
    "flex-1 rounded-2xl border border-purple-100 bg-white/95 px-4 py-4 shadow-sm transition duration-300 hover:-translate-y-0.5 hover:shadow-md"
  end

  defp priority_badge_class("high") do
    "inline-flex items-center rounded-full border border-rose-200 bg-rose-50 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-rose-600"
  end

  defp priority_badge_class("medium") do
    "inline-flex items-center rounded-full border border-amber-200 bg-amber-50 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-amber-600"
  end

  defp priority_badge_class(_priority) do
    "inline-flex items-center rounded-full border border-emerald-200 bg-emerald-50 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-emerald-600"
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
