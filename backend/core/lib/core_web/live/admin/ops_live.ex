defmodule CoreWeb.Admin.OpsLive do
  use CoreWeb, :live_view

  alias Core.AdminOps

  def mount(_params, _session, socket) do
    operations = AdminOps.list_operations()
    selected_operation = List.first(operations)
    form = build_form(selected_operation)

    {:ok,
     socket
     |> assign(:operations, operations)
     |> assign(:selected_operation, selected_operation)
     |> assign(:form, form)
     |> assign(:preview_result, nil)
     |> assign(:run_result, nil)
     |> assign(:pending_payload, nil)
     |> assign(:op_error, nil)}
  end

  def handle_event("select_op", %{"op" => op_param}, socket) do
    selected_operation = operation_from_param(socket.assigns.operations, op_param)
    form = build_form(selected_operation)

    {:noreply,
     socket
     |> assign(:selected_operation, selected_operation)
     |> assign(:form, form)
     |> assign(:preview_result, nil)
     |> assign(:run_result, nil)
     |> assign(:pending_payload, nil)
     |> assign(:op_error, nil)}
  end

  def handle_event("validate_op", %{"ops" => params}, socket) do
    form = build_form(socket.assigns.selected_operation, params)

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:preview_result, nil)
     |> assign(:run_result, nil)
     |> assign(:pending_payload, nil)
     |> assign(:op_error, nil)}
  end

  def handle_event("preview_op", %{"ops" => params}, socket) do
    selected_operation = socket.assigns.selected_operation
    form = build_form(selected_operation, params)
    actor = actor_from_socket(socket)

    case AdminOps.preview(selected_operation.id, params, actor) do
      {:ok, preview_result} ->
        {:noreply,
         socket
         |> assign(:form, form)
         |> assign(:preview_result, preview_result)
         |> assign(:run_result, nil)
         |> assign(:pending_payload, %{op_id: selected_operation.id, params: params})
         |> assign(:op_error, nil)}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:form, form)
         |> assign(:preview_result, nil)
         |> assign(:run_result, nil)
         |> assign(:pending_payload, nil)
         |> assign(:op_error, format_error(reason))}
    end
  end

  def handle_event("run_op", _params, socket) do
    case socket.assigns.pending_payload do
      nil ->
        {:noreply, assign(socket, :op_error, "Preview an operation before executing it.")}

      %{op_id: op_id, params: params} ->
        actor = actor_from_socket(socket)

        case AdminOps.run(op_id, params, actor) do
          {:ok, run_result} ->
            {:noreply,
             socket
             |> put_flash(:info, "Operation executed successfully.")
             |> assign(:run_result, run_result)
             |> assign(:preview_result, nil)
             |> assign(:pending_payload, nil)
             |> assign(:op_error, nil)}

          {:error, reason} ->
            {:noreply, assign(socket, :op_error, format_error(reason))}
        end
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="min-h-screen">
        <header class="border-b border-[color:var(--hub-border)]">
          <div class="mx-auto flex max-w-6xl items-center justify-between px-6 py-5">
            <div>
              <p class="font-display text-lg text-[var(--hub-accent-2)]">Admin Ops</p>
              <p class="mt-1 text-xs text-[var(--hub-muted)]">Action-driven operational controls for administrators.</p>
            </div>
            <div class="flex items-center gap-3">
              <a href={~p"/admin"} class="btn btn-secondary btn-sm">Back to dashboard</a>
            </div>
          </div>
        </header>

        <main class="mx-auto max-w-6xl px-6 py-10">
          <div class="grid gap-6 lg:grid-cols-2">
            <section class="hub-glass rounded-2xl p-5">
              <h2 class="text-base font-semibold text-[var(--hub-text)]">Operations</h2>
              <p class="mt-1 text-xs text-[var(--hub-muted)]">
                Select an action, provide required data, then preview before execution.
              </p>

              <div class="mt-4 grid gap-3 sm:grid-cols-2">
                <button
                  :for={operation <- @operations}
                  type="button"
                  phx-click="select_op"
                  phx-value-op={Atom.to_string(operation.id)}
                  class={operation_card_class(operation, @selected_operation)}
                >
                  <div class="flex items-center justify-between gap-2">
                    <p class="text-sm font-semibold text-[var(--hub-text)]"><%= operation.label %></p>
                    <span class={risk_badge_class(operation.risk)}><%= risk_label(operation.risk) %></span>
                  </div>
                  <p class="mt-2 text-xs text-[var(--hub-muted)]"><%= operation.description %></p>
                  <p class="mt-2 text-[11px] font-medium text-[var(--hub-muted)]">
                    Requires: <%= required_params_label(operation.params) %>
                  </p>
                </button>
              </div>
            </section>

            <section class="hub-glass rounded-2xl p-5">
              <div class="flex items-center justify-between gap-3">
                <h2 class="text-base font-semibold text-[var(--hub-text)]"><%= @selected_operation.label %></h2>
                <span class={risk_badge_class(@selected_operation.risk)}>
                  <%= risk_label(@selected_operation.risk) %>
                </span>
              </div>
              <p class="mt-1 text-xs text-[var(--hub-muted)]"><%= @selected_operation.description %></p>

              <.form
                for={@form}
                as={:ops}
                id="admin-ops-form"
                phx-change="validate_op"
                phx-submit="preview_op"
                class="mt-4 space-y-4"
              >
                <input type="hidden" name="ops[op]" value={Atom.to_string(@selected_operation.id)} />

                <%= if requires_param?(@selected_operation, :email) do %>
                  <div>
                    <label for="ops_email" class="mb-1 block text-sm font-medium text-[var(--hub-text)]">
                      User email
                    </label>
                    <input
                      id="ops_email"
                      name="ops[email]"
                      type="email"
                      value={@form[:email].value}
                      placeholder="user@example.com"
                      class="w-full rounded-lg border border-[color:var(--hub-border)] bg-[var(--hub-surface)] px-3 py-2 text-sm text-[var(--hub-text)] focus:border-[color:var(--hub-accent)] focus:outline-none focus:ring-2 focus:ring-[color:var(--hub-accent)]/30"
                      required
                    />
                  </div>
                <% end %>

                <%= if requires_param?(@selected_operation, :days_old) do %>
                  <div>
                    <label for="ops_days_old" class="mb-1 block text-sm font-medium text-[var(--hub-text)]">
                      Days old
                    </label>
                    <input
                      id="ops_days_old"
                      name="ops[days_old]"
                      type="number"
                      value={@form[:days_old].value}
                      min="1"
                      max="3650"
                      class="w-full rounded-lg border border-[color:var(--hub-border)] bg-[var(--hub-surface)] px-3 py-2 text-sm text-[var(--hub-text)] focus:border-[color:var(--hub-accent)] focus:outline-none focus:ring-2 focus:ring-[color:var(--hub-accent)]/30"
                      required
                    />
                  </div>
                <% end %>

                <%= if @selected_operation.confirm_phrase do %>
                  <div>
                    <label for="ops_confirm_text" class="mb-1 block text-sm font-medium text-[var(--hub-text)]">
                      <%= "Type #{@selected_operation.confirm_phrase} to allow execution" %>
                    </label>
                    <input
                      id="ops_confirm_text"
                      name="ops[confirm_text]"
                      type="text"
                      value={@form[:confirm_text].value}
                      placeholder={@selected_operation.confirm_phrase}
                      class="w-full rounded-lg border border-[color:var(--hub-border)] bg-[var(--hub-surface)] px-3 py-2 text-sm text-[var(--hub-text)] focus:border-[color:var(--hub-accent)] focus:outline-none focus:ring-2 focus:ring-[color:var(--hub-accent)]/30"
                    />
                  </div>
                <% end %>

                <div class="flex items-center gap-2">
                  <button type="submit" class="btn btn-secondary btn-sm">Preview operation</button>
                </div>
              </.form>

              <%= if @op_error do %>
                <div class={["mt-4 rounded-lg border border-[color:var(--tone-expense)]/30 px-3 py-2 text-sm", CoreWeb.FinanceComponents.tone_class("expense", :soft)]}>
                  <%= @op_error %>
                </div>
              <% end %>

              <%= if @preview_result do %>
                <div class="mt-5 rounded-xl border border-[color:var(--hub-border)] p-4 bg-[var(--hub-surface)]">
                  <p class="text-xs font-semibold uppercase tracking-wide text-[var(--hub-muted)]">Preview</p>
                  <div class="mt-2 space-y-2 text-sm">
                    <div :for={{label, value} <- result_rows(@preview_result)} class="flex items-start justify-between gap-4">
                      <span class="text-[var(--hub-muted)]"><%= label %></span>
                      <span class="text-right font-medium text-[var(--hub-text)]"><%= value %></span>
                    </div>
                  </div>
                  <button type="button" phx-click="run_op" class="btn btn-primary btn-sm mt-4">
                    Run operation
                  </button>
                </div>
              <% end %>

              <%= if @run_result do %>
                <div class="mt-4 rounded-xl border border-[color:var(--tone-income)]/30 bg-[color:var(--tone-income)]/10 p-4">
                  <p class={["text-xs font-semibold uppercase tracking-wide", CoreWeb.FinanceComponents.tone_class("income", :text)]}>Execution result</p>
                  <div class="mt-2 space-y-2 text-sm">
                    <div :for={{label, value} <- result_rows(@run_result)} class="flex items-start justify-between gap-4">
                      <span class={CoreWeb.FinanceComponents.tone_class("income", :text)}><%= label %></span>
                      <span class="text-right font-medium text-[var(--hub-text)]"><%= value %></span>
                    </div>
                  </div>
                </div>
              <% end %>
            </section>
          </div>
        </main>
      </div>
    </Layouts.app>
    """
  end

  defp operation_from_param(operations, op_param) do
    Enum.find(operations, List.first(operations), fn operation ->
      Atom.to_string(operation.id) == to_string(op_param || "")
    end)
  end

  defp build_form(operation, params \\ %{}) do
    defaults = %{
      "op" => Atom.to_string(operation.id),
      "email" => "",
      "days_old" => "90",
      "confirm_text" => ""
    }

    defaults
    |> Map.merge(stringify_keys(params))
    |> to_form(as: :ops)
  end

  defp stringify_keys(params) when is_map(params) do
    Enum.reduce(params, %{}, fn {key, value}, acc ->
      Map.put(acc, to_string(key), value)
    end)
  end

  defp stringify_keys(_), do: %{}

  defp operation_card_class(operation, selected_operation) do
    selected? = operation.id == selected_operation.id

    base =
      "w-full rounded-xl border p-4 text-left transition-colors focus:outline-none focus:ring-2 focus:ring-[color:var(--hub-accent)]/40"

    if selected? do
      base <>
        " border-[color:var(--hub-accent)]/60 bg-[color:var(--hub-accent)]/15 shadow-[0_10px_24px_-16px_rgba(139,92,246,0.55)]"
    else
      base <>
        " border-[color:var(--hub-border)] bg-[var(--hub-surface)] hover:border-[color:var(--hub-accent)]/40 hover:bg-[color:var(--hub-accent)]/10"
    end
  end

  defp risk_badge_class(:safe) do
    [
      "inline-flex items-center rounded-full border border-[color:var(--tone-income)]/30 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide",
      CoreWeb.FinanceComponents.tone_class("income", :soft)
    ]
  end

  defp risk_badge_class(:sensitive) do
    [
      "inline-flex items-center rounded-full border border-[color:var(--tone-review)]/30 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide",
      CoreWeb.FinanceComponents.tone_class("review", :soft)
    ]
  end

  defp risk_badge_class(:destructive) do
    [
      "inline-flex items-center rounded-full border border-[color:var(--tone-expense)]/30 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide",
      CoreWeb.FinanceComponents.tone_class("expense", :soft)
    ]
  end

  defp risk_badge_class(_risk) do
    [
      "inline-flex items-center rounded-full border border-[color:var(--hub-border)] px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide",
      CoreWeb.FinanceComponents.tone_class("muted", :soft)
    ]
  end

  defp risk_label(:safe), do: "Safe"
  defp risk_label(:sensitive), do: "Sensitive"
  defp risk_label(:destructive), do: "Destructive"
  defp risk_label(_risk), do: "Unknown"

  defp required_params_label([]), do: "None"

  defp required_params_label(params) do
    params
    |> Enum.map(fn param ->
      param
      |> Atom.to_string()
      |> String.replace("_", " ")
    end)
    |> Enum.join(", ")
  end

  defp requires_param?(operation, param), do: param in operation.params

  defp result_rows(result) when is_map(result) do
    summary_row =
      case Map.get(result, :summary) do
        nil -> []
        summary -> [{"Summary", format_value(summary)}]
      end

    detail_rows =
      result
      |> Map.drop([:summary, :operation])
      |> Enum.map(fn {key, value} -> {humanize_key(key), format_value(value)} end)
      |> Enum.sort_by(fn {label, _value} -> label end)

    summary_row ++ detail_rows
  end

  defp result_rows(_result), do: []

  defp humanize_key(key) when is_atom(key) do
    key
    |> Atom.to_string()
    |> humanize_key()
  end

  defp humanize_key(key) when is_binary(key) do
    key
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp format_value(nil), do: "N/A"
  defp format_value(value) when is_boolean(value), do: to_string(value)
  defp format_value(value) when is_integer(value), do: Integer.to_string(value)
  defp format_value(%NaiveDateTime{} = value), do: NaiveDateTime.to_iso8601(value)
  defp format_value(value) when is_binary(value), do: value
  defp format_value(value), do: inspect(value)

  defp actor_from_socket(socket) do
    user = socket.assigns.current_scope.user
    %{id: user.id, email: user.email}
  end

  defp format_error(:invalid_actor), do: "Invalid actor."
  defp format_error(:invalid_operation), do: "Invalid operation."
  defp format_error({:validation, message}), do: message
  defp format_error({:not_found, message}), do: message

  defp format_error({:error, %Ecto.Changeset{} = changeset}),
    do: "Database error: #{inspect(changeset.errors)}"

  defp format_error(reason), do: inspect(reason)
end
