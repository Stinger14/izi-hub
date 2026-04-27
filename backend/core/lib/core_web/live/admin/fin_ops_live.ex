defmodule CoreWeb.Admin.FinOpsLive do
  use CoreWeb, :live_view

  alias Core.Accounts
  alias Core.Finance

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: "FinOps")
     |> assign(result: nil, form_error: nil)
     |> assign_form(default_form_values())}
  end

  def handle_event("load_preset", %{"preset" => preset}, socket) do
    values =
      case preset do
        "expense" ->
          Map.merge(default_form_values(), %{
            "from" => "alerts@bank.com",
            "subject" => "Card purchase alert",
            "message_id" => "<expense-#{System.unique_integer([:positive])}@bank.com>",
            "text_body" => """
            Card purchase alert
            Merchant: Cafe Central
            Amount: USD 54.25
            """
          })

        "income" ->
          Map.merge(default_form_values(), %{
            "from" => "alerts@bank.com",
            "subject" => "Deposit alert",
            "message_id" => "<income-#{System.unique_integer([:positive])}@bank.com>",
            "text_body" => """
            Deposit alert
            From Payroll
            Amount: USD 1200.00
            """
          })

        _ ->
          default_form_values()
      end

    {:noreply, socket |> assign_form(values) |> assign(result: nil, form_error: nil)}
  end

  def handle_event("ingest_sample", %{"finops" => params}, socket) do
    with {:ok, user} <- fetch_target_user(params),
         {:ok, attrs} <- build_ingestion_attrs(params) do
      case Finance.ingest_email_transaction_candidate(user, attrs) do
        {:ok, :duplicate} ->
          {:noreply,
           socket
           |> assign_form(params)
           |> assign(result: %{status: :duplicate, target_user: user}, form_error: nil)}

        {:ok, transaction} ->
          {:noreply,
           socket
           |> assign_form(params)
           |> assign(
             result: %{status: :created, transaction: transaction, target_user: user},
             form_error: nil
           )
           |> put_flash(:info, "Sample email ingested into review queue.")}

        {:error, reason} ->
          {:noreply,
           socket
           |> assign_form(params)
           |> assign(
             result: %{status: :error, reason: reason, target_user: user},
             form_error: nil
           )}
      end
    else
      {:error, message} ->
        {:noreply, socket |> assign_form(params) |> assign(form_error: message, result: nil)}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="min-h-screen bg-slate-50 text-slate-900">
        <header class="border-b border-slate-200 bg-white/90 backdrop-blur">
          <div class="mx-auto flex max-w-6xl items-center justify-between px-6 py-5">
            <div>
              <p class="text-lg font-semibold tracking-tight text-emerald-700">FinOps</p>
              <p class="mt-1 text-xs text-slate-500">Internal finance ingestion tools for parser validation and review-queue testing.</p>
            </div>
            <div class="flex items-center gap-3">
              <a href={~p"/admin"} class="btn btn-secondary btn-sm">Back to dashboard</a>
            </div>
          </div>
        </header>

        <main class="mx-auto grid max-w-6xl gap-6 px-6 py-10 lg:grid-cols-[1.1fr_0.9fr]">
          <section class="rounded-lg border border-slate-200 bg-white p-6 shadow-sm">
            <div class="flex flex-wrap items-center justify-between gap-3">
              <div>
                <h1 class="text-xl font-semibold text-slate-950">Sample email ingestion</h1>
                <p class="mt-1 text-sm text-slate-500">Submit a bank-style email payload to create a pending-review transaction.</p>
              </div>
              <div class="flex gap-2">
                <button type="button" phx-click="load_preset" phx-value-preset="expense" class="btn btn-secondary btn-xs">
                  Load expense preset
                </button>
                <button type="button" phx-click="load_preset" phx-value-preset="income" class="btn btn-secondary btn-xs">
                  Load income preset
                </button>
              </div>
            </div>

            <.form for={@form} as={:finops} phx-submit="ingest_sample" class="mt-6 space-y-4">
              <div class="grid gap-4 sm:grid-cols-2">
                <.finops_input form={@form} field={:target_email} label="Target user email" type="email" placeholder="user@example.com" />
                <.finops_input form={@form} field={:provider} label="Provider" placeholder="bank_email" />
                <.finops_input form={@form} field={:from} label="From" type="email" placeholder="alerts@bank.com" />
                <.finops_input form={@form} field={:subject} label="Subject" placeholder="Card purchase alert" />
                <.finops_input form={@form} field={:message_id} label="Message ID" placeholder="<sample-1@bank.com>" />
                <.finops_input form={@form} field={:received_at} label="Received at UTC" type="datetime-local" />
              </div>

              <.finops_textarea form={@form} field={:text_body} label="Text body" placeholder="Card purchase alert&#10;Merchant: Cafe Central&#10;Amount: USD 54.25" />
              <.finops_textarea form={@form} field={:html_body} label="HTML body optional" placeholder="<p>Optional HTML copy</p>" rows="4" />

              <div :if={@form_error} class="rounded-lg border border-rose-200 bg-rose-50 px-3 py-2 text-sm text-rose-700">
                <%= @form_error %>
              </div>

              <div class="flex justify-end">
                <button type="submit" class="btn btn-primary btn-sm">Ingest sample</button>
              </div>
            </.form>
          </section>

          <section class="space-y-6">
            <div class="rounded-lg border border-slate-200 bg-white p-6 shadow-sm">
              <h2 class="text-lg font-semibold text-slate-950">What this does</h2>
              <div class="mt-4 space-y-3 text-sm leading-6 text-slate-600">
                <p>The payload is sent through the finance email parser and only creates `pending_review` transactions.</p>
                <p>Confirmed ledger metrics, budgets, and health do not change until the pending item is reviewed in Finance.</p>
                <p>Duplicate `message_id` values are deduped through the transaction `external_id` field.</p>
              </div>
            </div>

            <div class="rounded-lg border border-slate-200 bg-white p-6 shadow-sm">
              <h2 class="text-lg font-semibold text-slate-950">Last result</h2>
              <div class="mt-4">
                <%= case @result do %>
                  <% %{status: :created, transaction: transaction, target_user: user} -> %>
                    <div class="space-y-3">
                      <div class="rounded-lg border border-emerald-200 bg-emerald-50 px-3 py-2 text-sm text-emerald-800">
                        Created pending review transaction for <%= user.email %>.
                      </div>
                      <div class="space-y-2 text-sm">
                        <.result_row label="Amount" value={money(transaction.amount)} />
                        <.result_row label="Type" value={String.capitalize(transaction.type)} />
                        <.result_row label="Merchant" value={transaction.merchant || "Not set"} />
                        <.result_row label="Status" value={String.capitalize(transaction.status)} />
                        <.result_row label="Source" value={String.capitalize(transaction.source)} />
                        <.result_row label="External ID" value={transaction.external_id || "Not set"} />
                      </div>
                    </div>

                  <% %{status: :duplicate, target_user: user} -> %>
                    <div class="rounded-lg border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-800">
                      Duplicate message ignored for <%= user.email %>.
                    </div>

                  <% %{status: :error, reason: reason, target_user: user} -> %>
                    <div class="rounded-lg border border-rose-200 bg-rose-50 px-3 py-2 text-sm text-rose-700">
                      Ingestion failed for <%= user.email %>: <%= format_reason(reason) %>
                    </div>

                  <% _ -> %>
                    <p class="text-sm text-slate-500">No ingestion attempts yet.</p>
                <% end %>
              </div>
            </div>
          </section>
        </main>
      </div>
    </Layouts.app>
    """
  end

  attr :form, :any, required: true
  attr :field, :atom, required: true
  attr :label, :string, required: true
  attr :type, :string, default: "text"
  attr :placeholder, :string, default: nil

  defp finops_input(assigns) do
    field = assigns.form[assigns.field]
    assigns = assign(assigns, :field_data, field)

    ~H"""
    <div>
      <label for={@field_data.id} class="mb-1 block text-[11px] font-semibold uppercase tracking-wide text-slate-500">
        <%= @label %>
      </label>
      <input
        id={@field_data.id}
        name={@field_data.name}
        type={@type}
        value={@field_data.value}
        placeholder={@placeholder}
        class="w-full rounded-lg border border-slate-200 bg-white px-3 py-2.5 text-sm text-slate-900 outline-none transition focus:border-emerald-400 focus:ring-2 focus:ring-emerald-100"
      />
    </div>
    """
  end

  attr :form, :any, required: true
  attr :field, :atom, required: true
  attr :label, :string, required: true
  attr :placeholder, :string, default: nil
  attr :rows, :string, default: "8"

  defp finops_textarea(assigns) do
    field = assigns.form[assigns.field]
    assigns = assign(assigns, :field_data, field)

    ~H"""
    <div>
      <label for={@field_data.id} class="mb-1 block text-[11px] font-semibold uppercase tracking-wide text-slate-500">
        <%= @label %>
      </label>
      <textarea
        id={@field_data.id}
        name={@field_data.name}
        rows={@rows}
        placeholder={@placeholder}
        class="w-full rounded-lg border border-slate-200 bg-white px-3 py-2.5 text-sm text-slate-900 outline-none transition focus:border-emerald-400 focus:ring-2 focus:ring-emerald-100"
      ><%= @field_data.value %></textarea>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true

  defp result_row(assigns) do
    ~H"""
    <div class="flex items-center justify-between gap-4 border-b border-slate-100 py-2 last:border-b-0">
      <span class="text-slate-500"><%= @label %></span>
      <span class="font-semibold text-slate-900"><%= @value %></span>
    </div>
    """
  end

  defp assign_form(socket, values) do
    assign(socket, :form, to_form(values, as: :finops))
  end

  defp default_form_values do
    %{
      "target_email" => "",
      "provider" => "bank_email",
      "from" => "",
      "subject" => "",
      "message_id" => "<sample-#{System.unique_integer([:positive])}@bank.com>",
      "received_at" => datetime_local_value(DateTime.utc_now()),
      "text_body" => "",
      "html_body" => ""
    }
  end

  defp fetch_target_user(params) do
    email = params["target_email"] |> to_string() |> String.trim()

    case Accounts.get_user_by_email(email) do
      nil -> {:error, "Target user not found."}
      user -> {:ok, user}
    end
  end

  defp build_ingestion_attrs(params) do
    with {:ok, received_at} <- parse_received_at(params["received_at"]) do
      {:ok,
       %{
         "provider" => params["provider"],
         "message_id" => params["message_id"],
         "from" => params["from"],
         "subject" => params["subject"],
         "received_at" => received_at,
         "text_body" => params["text_body"],
         "html_body" => blank_to_nil(params["html_body"])
       }}
    end
  end

  defp parse_received_at(nil), do: {:error, "Received at is required."}
  defp parse_received_at(""), do: {:error, "Received at is required."}

  defp parse_received_at(value) do
    case NaiveDateTime.from_iso8601(value) do
      {:ok, naive_datetime} -> {:ok, DateTime.from_naive!(naive_datetime, "Etc/UTC")}
      {:error, _reason} -> parse_received_at_with_minutes(value)
    end
  end

  defp parse_received_at_with_minutes(value) do
    case NaiveDateTime.from_iso8601(value <> ":00") do
      {:ok, naive_datetime} -> {:ok, DateTime.from_naive!(naive_datetime, "Etc/UTC")}
      {:error, _reason} -> {:error, "Received at must be a valid datetime."}
    end
  end

  defp datetime_local_value(%DateTime{} = datetime) do
    naive_datetime = DateTime.to_naive(datetime)
    truncated = %{naive_datetime | second: 0, microsecond: {0, 0}}
    Calendar.strftime(truncated, "%Y-%m-%dT%H:%M")
  end

  defp money(%Decimal{} = amount), do: "$#{Decimal.round(amount, 2)}"
  defp money(_amount), do: "$0.00"

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp format_reason(:unsupported_email), do: "unsupported email"
  defp format_reason(:unparseable_email), do: "unparseable email"
  defp format_reason(other), do: to_string(other)
end
