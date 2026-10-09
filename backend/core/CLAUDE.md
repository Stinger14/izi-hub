This is a web application written using the Phoenix web framework.

## Project guidelines

- Use `mix precommit` alias when you are done with all changes and fix any pending issues
- Use the already included and available `:req` (`Req`) library for HTTP requests, **avoid** `:httpoison`, `:tesla`, and `:httpc`. Req is included by default and is the preferred HTTP client for Phoenix apps

### Phoenix v1.8 guidelines

- **Always** begin your LiveView templates with `<Layouts.app flash={@flash} ...>` which wraps all inner content
- The `MyAppWeb.Layouts` module is aliased in the `my_app_web.ex` file, so you can use it without needing to alias it again
- Anytime you run into errors with no `current_scope` assign:
  - You failed to follow the Authenticated Routes guidelines, or you failed to pass `current_scope` to `<Layouts.app>`
  - **Always** fix the `current_scope` error by moving your routes to the proper `live_session` and ensure you pass `current_scope` as needed
- Phoenix v1.8 moved the `<.flash_group>` component to the `Layouts` module. You are **forbidden** from calling `<.flash_group>` outside of the `layouts.ex` module
- Out of the box, `core_components.ex` imports an `<.icon name="hero-x-mark" class="w-5 h-5"/>` component for for hero icons. **Always** use the `<.icon>` component for icons, **never** use `Heroicons` modules or similar
- **Always** use the imported `<.input>` component for form inputs from `core_components.ex` when available. `<.input>` is imported and using it will save steps and prevent errors
- If you override the default input classes (`<.input class="myclass px-2 py-1 rounded-lg">)`) class with your own values, no default classes are inherited, so your
custom classes must fully style the input

## Finance app conventions

- Icons are hand-rolled, not a real Heroicons package. `CoreWeb.CoreComponents.icon/1` is a single `case` statement with inline SVGs for a fixed, small set of names. Using a `hero-*` name that isn't in that `case` silently renders a blank `<span>` — it does not raise or warn. Before using a new icon name anywhere in `core_web`, grep `core_components.ex` for it first; if it's missing, either pick one of the already-implemented names or add a real SVG `case` clause (don't guess path data from memory).
- Color/status meaning goes through `CoreWeb.FinanceComponents.tone_class/2`, not raw Tailwind colors. Tones are `"income"` (green), `"expense"` (red), `"budget"` (purple), `"debt"`/`"review"` (gold), `"muted"` (gray), each with `:text`, `:soft` (badge bg+text), and `:bar` variants, backed by `--tone-*` CSS vars in `app.css`. Any new status indicator, badge, or progress bar should resolve its color through this helper instead of hardcoding a hex/Tailwind class, so a widget's badge, bar, and text always agree with each other.
- Finance rides the IziHub theme: `Layouts.app` wraps every page in `.hub-shell`, which maps every `--fin-*`/`--tone-*`/`--btn-*` token onto the hub palette (plus `--fin-primary`/`--fin-on-primary` for filled active states like scope toggles). `.finance-shell` now only scopes finance-specific rules that read those tokens. `CoreWeb.FinanceComponents.fin_card/1` is the shared surface and carries `hub-glass`, so it renders as a glass panel — use it (or the `--fin-card`/`--fin-surface`/`--fin-border` tokens) for any new finance surface instead of hardcoding colors. ApexCharts needs literal colors, so the `@chart_*` attributes in `finance_components.ex` mirror the `--tone-*`/`--hub-*` values in `app.css`; change both together.
- **IziHub theme (site-wide).** The dark "Nebula violet" glass theme is IziHub's design system and the only theme: `Layouts.app` wraps every page (LiveViews and controller-rendered pages) in `.hub-shell`, which defines all tokens in `app.css`. The `hub-` prefix comes from the IziHub brand, not the `/hub` page, so `--hub-*` tokens and `.hub-shell`/`.hub-glass`/`.hub-gradient-text`/`.hub-glass-interactive` apply to any page. (`HubLive`, `CoreWeb.HubComponents` and `hub_card/1` are the `/hub` page itself.) Look: a lifted charcoal page (`--hub-bg` `#1C1B22`) washed with a CSS-only violet haze + starfield, Geist type (headings via `font-display`, heavier with tight tracking), and translucent blurred glass panels via `.hub-glass` (put it on every panel/popover; `fin_card` already carries it). Clickable glass cards add `.hub-glass-interactive` for the hover state, since `.hub-glass` owns the border. Role tokens: `--hub-primary` is a deep violet used only as a fill under white text (buttons, selected states), `--hub-secondary` violet-400 for links/icons, `--hub-accent-2` violet-300 for kicker labels, `--hub-accent` violet-500 for decoration and small marks like dots (glows, focus rings, hover borders — under 4.5:1 as text); `.hub-gradient-text` is the highlight treatment for a key phrase. Besides the finance tones, `.hub-shell` defines `--tone-info` (sky) for in-progress/informational states such as Office's WIP stage and roadmap notes; it is a CSS var only (no `tone_class/2` clause). `.hub-shell` also remaps `--fin-*`/`--tone-*`/`--btn-*` and the shared `--fx-*` effect tokens, and page-specific CSS (Profile `fx-stack-*`/`fx-contact-link`, admin `admin-console-*`, FinOps `finops-*`, `badge-wip`) is restyled under `.hub-shell`. `/hub` widgets live in `CoreWeb.HubComponents` (`hub_card/1` is the base surface) — add new ones there, color them through `--hub-*` tokens, and give unwired features an empty state rather than placeholder numbers.
- **Hub dashboard data.** `HubLive` loads real data for two cards and keeps the rest presentation-only. The Finance card reuses `Core.Finance` directly (`list_accounts/2` + `currency_totals/3` for the balance, `get_currency_summary/4` with `exclude_debt_payment_expenses: true` for this month, `check_budget_status/1` + `budget_remaining_pct/1` for the "left this month" bar) for the personal scope or the user's first household — don't duplicate `FinanceLive.assign_finance_data/1` logic. The Developer card reads `users.github_username` (set only through `User.github_username_changeset/2` / `Accounts.update_github_username/2`, never cast elsewhere) and loads `Core.GitHub.developer_stats/1` via `assign_async`, so GitHub latency never blocks the page; it uses the server's `GITHUB_TOKEN` and public data only (no per-user OAuth). In tests, seed `Core.GitHub.Cache` with `{{:developer_stats, login}, {now, result}}` instead of hitting the network. Creator (Facebook) stats are deferred: the view is a "coming soon" state until a Meta integration exists.
- **Office data is shared, and changes are live.** Calendar maths (`Office.calendar_counts/2` for one project's items, `calendar_counts_for_user/3` across active projects) and the hub's queries (`focus_tasks/3`, `agenda_for_day/2`, `next_status/1`, `get_user_work_item/2`) live in `Core.Office`, shared by `OfficeLive` and `HubLive` — don't re-derive them in a LiveView. Every successful `Core.Office` write broadcasts `{:office_changed, user_id}` on `"office:user:<id>"` via `broadcast_from(self(), …)`, so the writing LiveView (which already refreshes itself) skips its own echo while other tabs/pages reload. Any new Office write function must pipe its `{:ok, _}` result through `broadcast_change/2`; LiveViews subscribe with `Office.subscribe(user)` in a connected mount and handle `{:office_changed, _}` by reloading. In tests, a write made by the test process isn't echoed back to it, so to assert a broadcast, make the write in another process (`Task.async/1`).
- **Finance changes are live, scoped to the owner.** Every successful `Core.Finance` write pipes its result through `broadcast_change/1`, which reads the owner off the saved record and sends `{:finance_changed, {:user, id} | {:household, id}}` on `"finance:user:<id>"` / `"finance:household:<id>"` (via `broadcast_from(self(), …)`), so all household members' open pages update. It stays silent inside `Repo.transaction` (`Repo.in_transaction?/0`) — the outer function broadcasts once after commit (see `record_debt_payment/3`, `create_account_transfer/3`). Any new Finance write must end in `|> broadcast_change()`. `Finance.subscribe/1` joins the user's topic plus each household's; call `Finance.subscribe_household/1` when a household is created mid-session. Both Finance and Office LiveViews start their change `handle_info` with `CoreWeb.LiveReload.drain(tag)`, which discards already-queued duplicates so a burst (e.g. several ingested bank emails) causes one reload; Finance then reloads through `assign_finance_data/1`. Listener processes in tests must be started with `Task` (not `spawn`) to inherit the DB sandbox.
- **Styling a new page or component:** don't add a light wrapper background/text color — the shell already provides them; color through `--hub-*` tokens (`text-[var(--hub-text)]`, `text-[var(--hub-muted)]`, `border-[color:var(--hub-border)]`, …) instead of raw `purple-*`/`slate-*`/`white`/`gray-*` utilities; put `.hub-glass` on panels, cards and popovers; route status/meaning colors through `tone_class/2` (or `--tone-*`); keep text contrast ≥ 4.5:1; then run `mix precommit` and check the page at 1440px and 390px (the shared header must not overflow on phones).
- Charts are ApexCharts via the `ApexChart` hook in `app.js`: the hook element carries the whole chart config as JSON in `data-chart`, and the chart mounts into an inner `phx-update="ignore"` `[data-chart-target]` node so LiveView patches never wipe Apex's DOM. Build new charts through `cashflow_chart`/`spending_donut`-style function components that JSON-encode options server-side; don't hand-roll a second hook.
- Two ways content gets in front of the user — don't mix them:
  - **Sidebar sections** (`@active_section` / `@sections` in `finance_live.ex`) are full pages, switched via the `"show_section"` event. Most render a two-column `form (left) + list (right)` layout (see `accounts_panel`, `goal_panel`, `budgets_section`, `debts_section`) where the form is always visible on the page, no extra button needed to reveal it.
  - `focus_panel_modal` (`@focus_panel` / `@focus_panels`) is for quick contextual actions layered over whatever section is active (add transaction, create household), triggered via `"open_focus_panel"`. Reserve it for things that shouldn't interrupt navigation. If something becomes a primary destination (as Accounts and Goals did), move it to a full section and drop it from `@focus_panels` rather than keeping both paths alive.
- Money is always aggregated through `currency_totals/3`, `currency_codes/2`, and `sort_currency_totals/1`, and rendered with `money/2` / `money_totals/1` / `signed_money/1` — never `Enum.reduce` raw `Decimal`s across a list that might span DOP and USD. `money_totals/1` already renders a `"·"`-joined multi-currency string when a scope has more than one.
- New `Core.Finance` schemas (accounts, debts, budgets, savings goals, ...) follow one owner-scope pattern: `belongs_to :user` + `belongs_to :household`, a changeset validation that exactly one of `user_id`/`household_id` is set, and a matching Postgres `CHECK` constraint in the migration (`(user_id IS NOT NULL) <> (household_id IS NOT NULL)`). The context then gets `scope_query/2`, `scope_attrs/2`, `ensure_scope_access/2`, and `ensure_resource_owner/2` for free — reuse those instead of writing new authorization checks per schema.
- Progress bar direction is meaningful, not decorative. Budget bars (`budget_status_card`, `budget_progress_row`, the dashboard's "This month's budget" bar) represent **what's left** and deplete as spending grows (`budget_remaining_pct/1` = `100 - percent used`, clamped 0..100). Savings goal bars represent **progress toward a target** and fill up as you save. Don't copy one pattern into the other's use case.
- `FinanceLive.assign_finance_data/1` is the single place derived data gets recomputed (totals, groupings, summaries). After any mutation, call `assign_finance_data(socket)` again rather than patching individual assigns by hand — it keeps net worth, budget totals, and account summaries from drifting out of sync with each other.
- Account transfers are a linked pair of transactions (`counterpart_transaction_id` self-FK, set programmatically — never cast it). `Core.Finance.create_account_transfer/3` inserts both legs and shifts both account balances atomically; deleting either leg deletes both and reverses the balances. Any income/expense aggregate must exclude rows where `counterpart_transaction_id` is non-nil (the existing ones already do; `list_transactions` accepts `exclude_transfers: true`) — a transfer that leaks into income/expense sums silently skews cashflow and the saving rate.

<!-- usage-rules-start -->

<!-- phoenix:elixir-start -->
## Elixir guidelines

- Elixir lists **do not support index based access via the access syntax**

  **Never do this (invalid)**:

      i = 0
      mylist = ["blue", "green"]
      mylist[i]

  Instead, **always** use `Enum.at`, pattern matching, or `List` for index based list access, ie:

      i = 0
      mylist = ["blue", "green"]
      Enum.at(mylist, i)

- Elixir variables are immutable, but can be rebound, so for block expressions like `if`, `case`, `cond`, etc
  you *must* bind the result of the expression to a variable if you want to use it and you CANNOT rebind the result inside the expression, ie:

      # INVALID: we are rebinding inside the `if` and the result never gets assigned
      if connected?(socket) do
        socket = assign(socket, :val, val)
      end

      # VALID: we rebind the result of the `if` to a new variable
      socket =
        if connected?(socket) do
          assign(socket, :val, val)
        end

- **Never** nest multiple modules in the same file as it can cause cyclic dependencies and compilation errors
- **Never** use map access syntax (`changeset[:field]`) on structs as they do not implement the Access behaviour by default. For regular structs, you **must** access the fields directly, such as `my_struct.field` or use higher level APIs that are available on the struct if they exist, `Ecto.Changeset.get_field/2` for changesets
- Elixir's standard library has everything necessary for date and time manipulation. Familiarize yourself with the common `Time`, `Date`, `DateTime`, and `Calendar` interfaces by accessing their documentation as necessary. **Never** install additional dependencies unless asked or for date/time parsing (which you can use the `date_time_parser` package)
- Don't use `String.to_atom/1` on user input (memory leak risk)
- Predicate function names should not start with `is_` and should end in a question mark. Names like `is_thing` should be reserved for guards
- Elixir's builtin OTP primitives like `DynamicSupervisor` and `Registry`, require names in the child spec, such as `{DynamicSupervisor, name: MyApp.MyDynamicSup}`, then you can use `DynamicSupervisor.start_child(MyApp.MyDynamicSup, child_spec)`
- Use `Task.async_stream(collection, callback, options)` for concurrent enumeration with back-pressure. The majority of times you will want to pass `timeout: :infinity` as option

## Mix guidelines

- Read the docs and options before using tasks (by using `mix help task_name`)
- To debug test failures, run tests in a specific file with `mix test test/my_test.exs` or run all previously failed tests with `mix test --failed`
- `mix deps.clean --all` is **almost never needed**. **Avoid** using it unless you have good reason

## Test guidelines

- Use the shared fixtures in `test/support/fixtures.ex` (`user_fixture/1`, `admin_fixture/1`, `valid_password/0`), imported by `DataCase` and `ConnCase` — don't define per-file user fixtures. `config/test.exs` sets bcrypt to 1 log round so fixtures are cheap; never copy that setting into dev/prod config.
- **Always use `start_supervised!/1`** to start processes in tests as it guarantees cleanup between tests
- **Avoid** `Process.sleep/1` and `Process.alive?/1` in tests
  - Instead of sleeping to wait for a process to finish, **always** use `Process.monitor/1` and assert on the DOWN message:

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}

   - Instead of sleeping to synchronize before the next call, **always** use `_ = :sys.get_state/1` to ensure the process has handled prior messages
<!-- phoenix:elixir-end -->

<!-- phoenix:phoenix-start -->
## Phoenix guidelines

- Remember Phoenix router `scope` blocks include an optional alias which is prefixed for all routes within the scope. **Always** be mindful of this when creating routes within a scope to avoid duplicate module prefixes.

- You **never** need to create your own `alias` for route definitions! The `scope` provides the alias, ie:

      scope "/admin", AppWeb.Admin do
        pipe_through :browser

        live "/users", UserLive, :index
      end

  the UserLive route would point to the `AppWeb.Admin.UserLive` module

- `Phoenix.View` no longer is needed or included with Phoenix, don't use it
<!-- phoenix:phoenix-end -->

<!-- phoenix:ecto-start -->
## Ecto Guidelines

- **Always** preload Ecto associations in queries when they'll be accessed in templates, ie a message that needs to reference the `message.user.email`
- Remember `import Ecto.Query` and other supporting modules when you write `seeds.exs`
- `Ecto.Schema` fields always use the `:string` type, even for `:text`, columns, ie: `field :name, :string`
- `Ecto.Changeset.validate_number/2` **DOES NOT SUPPORT the `:allow_nil` option**. By default, Ecto validations only run if a change for the given field exists and the change value is not nil, so such as option is never needed
- You **must** use `Ecto.Changeset.get_field(changeset, :field)` to access changeset fields
- Fields which are set programatically, such as `user_id`, must not be listed in `cast` calls or similar for security purposes. Instead they must be explicitly set when creating the struct
- **Always** invoke `mix ecto.gen.migration migration_name_using_underscores` when generating migration files, so the correct timestamp and conventions are applied
<!-- phoenix:ecto-end -->

<!-- usage-rules-end -->