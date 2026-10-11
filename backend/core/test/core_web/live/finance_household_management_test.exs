defmodule CoreWeb.FinanceHouseholdManagementTest do
  use CoreWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Core.{Accounts, Repo}
  alias Core.Accounts.Household

  setup do
    owner = user_fixture(%{full_name: "Olivia Owner"})
    member = user_fixture(%{full_name: "Mateo Member"})
    {:ok, household} = Accounts.create_household(owner, %{"name" => "Garcia Home"})
    {:ok, _} = Accounts.add_household_member(owner, household, member)
    %{owner: owner, member: member, household: household}
  end

  defp open_panel(conn, user) do
    {:ok, view, _html} = live(init_test_session(conn, user_id: user.id), ~p"/finance")
    render_click(view, "set_ownership_scope", %{"scope" => "household"})
    render_click(view, "open_household_panel", %{})
    view
  end

  test "the owner renames the household", %{conn: conn, owner: owner, household: household} do
    view = open_panel(conn, owner)
    render_click(view, "open_household_rename", %{})

    html =
      view |> form("#household-rename-form", household: %{name: "Casa Garcia"}) |> render_submit()

    assert html =~ "Household renamed"
    assert Repo.get!(Household, household.id).name == "Casa Garcia"
  end

  test "the owner removes a member after confirming", %{
    conn: conn,
    owner: owner,
    member: member,
    household: household
  } do
    view = open_panel(conn, owner)

    html = view |> element(~s(button[aria-label="Remove Mateo Member"])) |> render_click()
    assert html =~ "Remove “Mateo Member”?"

    html = view |> element(~s(button[aria-label="Confirm remove Mateo Member"])) |> render_click()
    assert html =~ "Member removed"
    refute Accounts.user_household?(member, household.id)
  end

  test "the owner can't remove themselves", %{conn: conn, owner: owner} do
    view = open_panel(conn, owner)
    refute has_element?(view, ~s(button[aria-label="Remove Olivia Owner"]))
  end

  test "a member leaves and is switched back to personal", %{
    conn: conn,
    member: member,
    household: household
  } do
    view = open_panel(conn, member)
    refute has_element?(view, "#household-danger-zone")
    refute has_element?(view, "button[phx-click=open_household_rename]")

    render_click(view, "request_leave_household", %{})
    html = render_click(view, "leave_household", %{})

    assert html =~ "You left the household"
    refute Accounts.user_household?(member, household.id)
  end

  test "deleting needs the exact name", %{conn: conn, owner: owner, household: household} do
    view = open_panel(conn, owner)
    render_click(view, "open_household_delete", %{})

    html = view |> form("#household-delete-form", confirmation: "Garcia") |> render_submit()
    assert html =~ "Type the household&#39;s name exactly to confirm"
    assert Repo.get(Household, household.id)

    html = view |> form("#household-delete-form", confirmation: "garcia home") |> render_submit()
    assert html =~ "Garcia Home was deleted"
    refute Repo.get(Household, household.id)
  end

  test "the other member's open page drops the deleted household live", %{
    conn: conn,
    owner: owner,
    member: member,
    household: household
  } do
    {:ok, member_view, html} = live(init_test_session(conn, user_id: member.id), ~p"/finance")
    assert html =~ "Garcia Home"

    {:ok, _} = Accounts.delete_household(owner, household, "Garcia Home")

    refute render(member_view) =~ "Garcia Home"
  end
end
