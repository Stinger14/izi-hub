defmodule CoreWeb.StudioLive do
  @moduledoc """
  `/studio`: Polo Studio, where a creator plans content pieces and has the AI
  write hooks, scripts and captions for them.

  Context: reads and writes through `Core.Studio` and reloads on
  `{:studio_changed, _}` from other tabs. AI calls go through
  `Core.Studio.PoloClient` in `start_async`, so a minute-long generation never
  blocks the page; the task carries the piece it was started for, so switching
  pieces mid-generation still saves the draft to the right one.
  """

  use CoreWeb, :live_view

  import CoreWeb.FinanceComponents, only: [tone_class: 2]

  alias Core.Studio
  alias Core.Studio.{Piece, PoloClient}

  @generate_types ~w(hooks script caption)

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Studio.subscribe(current_user(socket))

    {:ok,
     socket
     |> assign(
       page_title: "Studio",
       generating: nil,
       selected: nil,
       confirming_delete: false,
       new_form: new_piece_form()
     )
     |> assign_selected(nil)
     |> assign_pieces()}
  end

  @impl true
  def handle_event("create_piece", %{"piece" => params}, socket) do
    case Studio.create_piece(current_user(socket), params) do
      {:ok, piece} ->
        {:noreply,
         socket
         |> assign(new_form: new_piece_form())
         |> assign_selected(piece)
         |> assign_pieces()}

      {:error, changeset} ->
        {:noreply, assign(socket, new_form: to_form(changeset, as: :piece))}
    end
  end

  def handle_event("select_piece", %{"id" => id}, socket) do
    {:noreply, assign_selected(socket, Studio.get_piece(current_user(socket), id))}
  end

  def handle_event(
        "validate_piece",
        %{"piece" => params},
        %{assigns: %{selected: %Piece{}}} = socket
      ) do
    form =
      socket.assigns.selected
      |> Piece.changeset(params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, piece_form: form)}
  end

  def handle_event(
        "save_piece",
        %{"piece" => params},
        %{assigns: %{selected: %Piece{} = piece}} = socket
      ) do
    case Studio.update_piece(current_user(socket), piece, params) do
      {:ok, piece} ->
        {:noreply,
         socket |> assign_selected(piece) |> assign_pieces() |> put_flash(:info, "Piece saved.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, piece_form: to_form(changeset))}

      {:error, :forbidden} ->
        {:noreply,
         socket |> assign_selected(nil) |> put_flash(:error, "You can't edit that piece.")}
    end
  end

  def handle_event("request_delete", _params, socket),
    do: {:noreply, assign(socket, confirming_delete: true)}

  def handle_event("cancel_delete", _params, socket),
    do: {:noreply, assign(socket, confirming_delete: false)}

  def handle_event("confirm_delete", _params, %{assigns: %{selected: %Piece{} = piece}} = socket) do
    case Studio.delete_piece(current_user(socket), piece) do
      {:ok, _piece} ->
        {:noreply, socket |> assign_selected(nil) |> assign_pieces()}

      {:error, _reason} ->
        {:noreply,
         socket
         |> assign(confirming_delete: false)
         |> put_flash(:error, "Couldn't delete that piece.")}
    end
  end

  def handle_event("choose_draft", %{"id" => id}, socket) do
    user = current_user(socket)

    with %{} = draft <- Studio.get_draft(user, id),
         {:ok, _draft} <- Studio.choose_draft(user, draft) do
      {:noreply, assign_drafts(socket)}
    else
      _ -> {:noreply, put_flash(socket, :error, "Couldn't use that draft.")}
    end
  end

  # `type` comes from the browser, so only known helpers run; a piece must be
  # selected and nothing else generating, so a double-click can't pay twice.
  def handle_event(
        "generate",
        %{"type" => type},
        %{assigns: %{selected: %Piece{} = piece, generating: nil}} = socket
      )
      when type in @generate_types do
    {:noreply,
     socket
     |> assign(generating: type)
     |> start_async(:generate, fn -> {type, piece, run(type, piece)} end)}
  end

  def handle_event("generate", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_async(:generate, {:ok, {type, piece, {:ok, body}}}, socket) do
    {:noreply, socket |> assign(generating: nil) |> save_result(type, piece, body)}
  end

  def handle_async(:generate, {:ok, {_type, _piece, {:error, {_status, message}}}}, socket) do
    {:noreply, socket |> assign(generating: nil) |> put_flash(:error, message)}
  end

  def handle_async(:generate, {:exit, _reason}, socket) do
    {:noreply,
     socket |> assign(generating: nil) |> put_flash(:error, "Generation failed. Try again.")}
  end

  @impl true
  def handle_info({:studio_changed, _user_id}, socket) do
    CoreWeb.LiveReload.drain(:studio_changed)
    {:noreply, assign_pieces(socket)}
  end

  defp run("hooks", piece), do: PoloClient.hooks(piece)
  defp run("script", piece), do: PoloClient.script(piece)
  defp run("caption", piece), do: PoloClient.caption(piece)

  defp save_result(socket, type, piece, body) do
    case Studio.save_draft(current_user(socket), piece, type, body) do
      {:ok, _draft} ->
        assign_drafts(socket)

      {:error, _reason} ->
        put_flash(socket, :error, "That piece is gone, so the draft wasn't saved.")
    end
  end

  # Reloads the list and refreshes the selected piece from it. The edit form is
  # left alone so another tab's change doesn't wipe what's being typed here;
  # if the selected piece was deleted elsewhere, the selection clears.
  defp assign_pieces(socket) do
    pieces = Studio.list_pieces(current_user(socket))
    socket = assign(socket, pieces: pieces, pieces_by_status: Enum.group_by(pieces, & &1.status))

    with %Piece{id: id} <- socket.assigns.selected,
         %Piece{} = fresh <- Enum.find(pieces, &(&1.id == id)) do
      socket |> assign(selected: fresh) |> assign_drafts()
    else
      nil -> socket
      _gone -> assign_selected(socket, nil)
    end
  end

  # The one place that sets everything about the selection, so the piece, its
  # form, its drafts and the delete prompt never disagree.
  defp assign_selected(socket, nil),
    do: assign(socket, selected: nil, piece_form: nil, drafts: [], confirming_delete: false)

  defp assign_selected(socket, %Piece{} = piece) do
    socket
    |> assign(
      selected: piece,
      piece_form: to_form(Piece.changeset(piece, %{})),
      confirming_delete: false
    )
    |> assign_drafts()
  end

  defp assign_drafts(%{assigns: %{selected: nil}} = socket), do: assign(socket, drafts: [])

  defp assign_drafts(%{assigns: %{selected: piece}} = socket),
    do: assign(socket, drafts: Studio.list_drafts(piece))

  defp new_piece_form, do: to_form(Piece.changeset(%Piece{}, %{}), as: :piece)

  defp current_user(socket), do: socket.assigns.current_scope.user

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} workspace={:studio}>
      <main class="mx-auto grid max-w-6xl gap-5 px-4 pb-16 pt-8 sm:px-6 lg:grid-cols-[minmax(0,20rem)_minmax(0,1fr)]">
        <section class="hub-glass min-w-0 rounded-2xl p-4">
          <h1 class="font-display text-2xl text-[var(--hub-text)]">Studio</h1>

          <.form for={@new_form} id="new-piece-form" phx-submit="create_piece" class="mt-3 flex gap-2">
            <input
              type="text"
              id="new-piece-title"
              name={@new_form[:title].name}
              value={@new_form[:title].value}
              placeholder="New idea…"
              aria-label="New piece title"
              maxlength="140"
              class={input_class(@new_form[:title].errors)}
            />
            <.icon_button type="submit" icon="hero-plus" label="Add piece" />
          </.form>

          <p :if={@pieces == []} class="mt-6 text-sm text-[var(--hub-muted)]">
            Add an idea above to start your first piece.
          </p>

          <div :for={status <- Piece.statuses()} :if={@pieces_by_status[status]} class="mt-5">
            <h2 class="text-[11px] font-semibold uppercase tracking-wide text-[var(--hub-muted)]">
              <%= status_label(status) %>
            </h2>
            <ul class="mt-2 space-y-1">
              <li :for={piece <- @pieces_by_status[status]}>
                <button
                  type="button"
                  id={"piece-#{piece.id}"}
                  phx-click="select_piece"
                  phx-value-id={piece.id}
                  aria-current={@selected && @selected.id == piece.id && "true"}
                  class={[
                    "flex w-full items-center gap-2 rounded-xl px-3 py-2 text-left text-sm transition",
                    if(@selected && @selected.id == piece.id,
                      do: "bg-[var(--fin-primary)] text-[var(--fin-on-primary)]",
                      else: "text-[var(--hub-text)] hover:bg-[var(--hub-surface)]"
                    )
                  ]}
                >
                  <span class="min-w-0 flex-1 truncate"><%= piece.title %></span>
                  <span class="shrink-0 text-[11px] opacity-80"><%= kind_label(piece.kind) %></span>
                </button>
              </li>
            </ul>
          </div>
        </section>

        <section class="min-w-0 space-y-5">
          <div :if={!@selected} class="hub-glass rounded-2xl p-6 text-sm text-[var(--hub-muted)]">
            Pick a piece, or add an idea, to write for it.
          </div>

          <div :if={@selected} id="piece-panel" class="hub-glass rounded-2xl p-5">
            <div :if={@confirming_delete} class="mb-4 flex flex-wrap items-center justify-between gap-2">
              <span class="min-w-0 truncate text-sm text-[var(--hub-text)]">Delete “<%= @selected.title %>”?</span>
              <span class="flex gap-2">
                <button type="button" phx-click="confirm_delete" class="btn btn-danger btn-xs">Delete</button>
                <button type="button" phx-click="cancel_delete" class="btn btn-ghost btn-xs">Cancel</button>
              </span>
            </div>

            <.form
              for={@piece_form}
              id="piece-form"
              phx-change="validate_piece"
              phx-submit="save_piece"
              class="space-y-3"
            >
              <div class="flex items-start gap-2">
                <div class="min-w-0 flex-1">
                  <.text_field form={@piece_form} field={:title} label="Title" />
                </div>
                <span class={["mt-6 shrink-0 rounded-full px-2 py-0.5 text-[11px] font-semibold", tone_class(status_tone(@selected.status), :soft)]}>
                  <%= status_label(@selected.status) %>
                </span>
                <.icon_button
                  :if={!@confirming_delete}
                  class="mt-5"
                  icon="hero-trash"
                  label="Delete piece"
                  tone="danger"
                  phx-click="request_delete"
                />
              </div>

              <div class="grid gap-3 sm:grid-cols-3">
                <.select_field form={@piece_form} field={:kind} label="Kind" options={Enum.map(Piece.kinds(), &{kind_label(&1), &1})} />
                <.select_field form={@piece_form} field={:language} label="Language" options={[{"Español", "es"}, {"English", "en"}]} />
                <.select_field form={@piece_form} field={:status} label="Status" options={Enum.map(Piece.statuses(), &{status_label(&1), &1})} />
              </div>

              <label class="block">
                <span class={label_class()}>Notes</span>
                <textarea
                  id={@piece_form[:notes].id}
                  name={@piece_form[:notes].name}
                  rows="5"
                  placeholder="What's it about? Key points, a story, the angle… The AI writes from this."
                  class={input_class([])}
                ><%= Phoenix.HTML.Form.normalize_value("textarea", @piece_form[:notes].value) %></textarea>
              </label>

              <div class="flex justify-end">
                <button type="submit" phx-disable-with="Saving…" class="btn btn-primary btn-sm">Save piece</button>
              </div>
            </.form>

            <div class="mt-5 flex flex-wrap gap-2 border-t border-[color:var(--hub-border)] pt-4">
              <button
                :for={type <- ~w(hooks script caption)}
                type="button"
                id={"generate-#{type}"}
                phx-click="generate"
                phx-value-type={type}
                disabled={@generating != nil}
                class="btn btn-ghost btn-sm"
              >
                <%= if @generating == type, do: "Writing…", else: draft_label(type) %>
              </button>
            </div>
          </div>

          <div :if={@selected && @drafts == []} class="text-sm text-[var(--hub-muted)]">
            Save some notes, then pick Hooks, Script or Caption to have the AI write a draft.
          </div>

          <article
            :for={draft <- @drafts}
            id={"draft-#{draft.id}"}
            class={[
              "hub-glass rounded-2xl p-5",
              draft.chosen && "border-[color:var(--hub-accent)]"
            ]}
          >
            <header class="mb-3 flex items-center gap-2">
              <h2 class="font-display text-base text-[var(--hub-text)]"><%= draft_label(draft.type) %></h2>
              <span :if={draft.chosen} class={["rounded-full px-2 py-0.5 text-[11px] font-semibold", tone_class("income", :soft)]}>
                In use
              </span>
              <span class="ml-auto text-[11px] text-[var(--hub-muted)]">
                <%= Calendar.strftime(draft.inserted_at, "%b %-d, %H:%M") %>
              </span>
              <.icon_button
                :if={!draft.chosen}
                icon="hero-check"
                label="Use this draft"
                phx-click="choose_draft"
                phx-value-id={draft.id}
              />
            </header>
            <.draft_body draft={draft} />
          </article>
        </section>
      </main>
    </Layouts.app>
    """
  end

  attr :draft, Core.Studio.Draft, required: true

  # `body` is the service's JSON as stored, so keys are strings.
  defp draft_body(%{draft: %{type: "hooks"}} = assigns) do
    ~H"""
    <ul class="space-y-2">
      <li :for={{hook, i} <- Enum.with_index(@draft.body["hooks"] || [])} class="flex items-start gap-2">
        <div class="min-w-0 flex-1">
          <p class="text-sm text-[var(--hub-text)]"><%= hook["text"] %></p>
          <p class="text-[11px] text-[var(--hub-muted)]"><%= hook["angle"] %></p>
        </div>
        <.copy_button id={"copy-#{@draft.id}-#{i}"} value={hook["text"]} label="Copy hook" />
      </li>
    </ul>
    """
  end

  defp draft_body(%{draft: %{type: "script"}} = assigns) do
    ~H"""
    <div class="space-y-3 text-sm text-[var(--hub-text)]">
      <div class="flex items-start gap-2">
        <p class="min-w-0 flex-1 font-semibold">
          <%= @draft.body["title"] %>
          <span class="font-normal text-[var(--hub-muted)]">· ~<%= @draft.body["estimated_seconds"] %>s</span>
        </p>
        <.copy_button id={"copy-#{@draft.id}"} value={script_text(@draft.body)} label="Copy script" />
      </div>
      <p><span class={label_class()}>Hook</span><%= @draft.body["hook"] %></p>
      <ol class="space-y-2">
        <li :for={beat <- @draft.body["beats"] || []} class="rounded-xl bg-[var(--hub-surface)] px-3 py-2">
          <p class="text-[11px] font-semibold uppercase tracking-wide text-[var(--hub-accent-2)]"><%= beat["label"] %></p>
          <p><%= beat["says"] %></p>
          <p class="text-xs text-[var(--hub-muted)]"><%= beat["shows"] %></p>
        </li>
      </ol>
      <p><span class={label_class()}>Call to action</span><%= @draft.body["cta"] %></p>
    </div>
    """
  end

  defp draft_body(%{draft: %{type: "caption"}} = assigns) do
    ~H"""
    <div class="space-y-3">
      <div :for={{variant, i} <- Enum.with_index(@draft.body["variants"] || [])} class="flex items-start gap-2 rounded-xl bg-[var(--hub-surface)] px-3 py-2">
        <div class="min-w-0 flex-1 space-y-2 text-sm text-[var(--hub-text)]">
          <p class="whitespace-pre-line"><%= variant["caption"] %></p>
          <p class="text-[var(--hub-muted)]"><%= variant["cta"] %></p>
        </div>
        <.copy_button
          id={"copy-#{@draft.id}-#{i}"}
          value={caption_text(variant, @draft.body["hashtags"])}
          label="Copy caption with hashtags"
        />
      </div>
      <p class="text-xs text-[var(--hub-secondary)]"><%= hashtags_text(@draft.body["hashtags"]) %></p>
    </div>
    """
  end

  defp draft_body(assigns) do
    ~H"""
    <pre class="overflow-x-auto whitespace-pre-wrap text-xs text-[var(--hub-muted)]"><%= Jason.encode!(@draft.body, pretty: true) %></pre>
    """
  end

  attr :id, :string, required: true
  attr :value, :string, required: true
  attr :label, :string, required: true

  # The CopyToClipboard hook (app.js) copies data-copy-value and flags data-copied.
  defp copy_button(assigns) do
    ~H"""
    <.icon_button
      id={@id}
      icon="hero-clipboard"
      label={@label}
      phx-hook="CopyToClipboard"
      data-copy-value={@value}
      data-copy-title={@label}
      class="data-[copied]:text-[var(--tone-income)]"
    />
    """
  end

  attr :form, Phoenix.HTML.Form, required: true
  attr :field, :atom, required: true
  attr :label, :string, required: true

  defp text_field(assigns) do
    assigns = assign(assigns, :f, assigns.form[assigns.field])

    ~H"""
    <label class="block">
      <span class={label_class()}><%= @label %></span>
      <input
        type="text"
        id={@f.id}
        name={@f.name}
        value={@f.value}
        maxlength="140"
        aria-invalid={@f.errors != [] && "true"}
        class={input_class(@f.errors)}
      />
      <span :for={{message, _opts} <- @f.errors} class={["mt-1 block text-xs", tone_class("expense", :text)]}>
        <%= @label %> <%= message %>
      </span>
    </label>
    """
  end

  attr :form, Phoenix.HTML.Form, required: true
  attr :field, :atom, required: true
  attr :label, :string, required: true
  attr :options, :list, required: true

  defp select_field(assigns) do
    assigns = assign(assigns, :f, assigns.form[assigns.field])

    ~H"""
    <label class="block">
      <span class={label_class()}><%= @label %></span>
      <select id={@f.id} name={@f.name} class={input_class(@f.errors)}>
        <%= Phoenix.HTML.Form.options_for_select(@options, @f.value) %>
      </select>
    </label>
    """
  end

  defp label_class,
    do: "mb-1 block text-[11px] font-semibold uppercase tracking-wide text-[var(--hub-muted)]"

  defp input_class(errors) do
    [
      "w-full rounded-xl border bg-[var(--hub-surface)] px-3 py-2 text-sm text-[var(--hub-text)] outline-none focus:border-[color:var(--hub-accent)]",
      if(errors == [],
        do: "border-[color:var(--hub-border)]",
        else: "border-[color:var(--tone-expense)]"
      )
    ]
  end

  defp status_label("idea"), do: "Idea"
  defp status_label("scripting"), do: "Scripting"
  defp status_label("ready"), do: "Ready"
  defp status_label("published"), do: "Published"

  defp status_tone("idea"), do: "muted"
  defp status_tone("scripting"), do: "review"
  defp status_tone("ready"), do: "budget"
  defp status_tone("published"), do: "income"

  defp kind_label("video"), do: "Video"
  defp kind_label("reel"), do: "Reel"
  defp kind_label("post"), do: "Post"
  defp kind_label("live"), do: "Live"

  defp draft_label("hooks"), do: "Hooks"
  defp draft_label("script"), do: "Script"
  defp draft_label("caption"), do: "Caption"
  defp draft_label("repurpose"), do: "Repurpose"

  defp hashtags_text(tags), do: Enum.map_join(tags || [], " ", &"##{&1}")

  defp caption_text(variant, tags) do
    [variant["caption"], variant["cta"], hashtags_text(tags)]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join("\n\n")
  end

  defp script_text(body) do
    beats = Enum.map(body["beats"] || [], &"#{&1["label"]}: #{&1["says"]}")
    Enum.join([body["title"], body["hook"] | beats] ++ [body["cta"]], "\n\n")
  end
end
