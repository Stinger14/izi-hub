defmodule CoreWeb.InvitationControllerTest do
  use CoreWeb.ConnCase, async: true

  alias Core.Accounts

  def invite_url(token), do: "/invites/#{token}"

  setup do
    owner = user_fixture(%{full_name: "Olivia Owner"})
    {:ok, household} = Accounts.create_household(owner, %{"name" => "Garcia Home"})
    %{owner: owner, household: household}
  end

  defp invite(ctx, email) do
    {:ok, _invitation, path} =
      Accounts.invite_to_household(ctx.owner, ctx.household, email, &__MODULE__.invite_url/1)

    {path, path |> String.split("/") |> List.last()}
  end

  test "a signed-in user accepts and lands on the household", %{conn: conn} = ctx do
    user = user_fixture(%{email: "invitee@example.com"})
    {path, token} = invite(ctx, "invitee@example.com")
    conn = log_in_user(conn, user)

    html = conn |> get(path) |> html_response(200)
    assert html =~ "Join Garcia Home"
    assert html =~ "Olivia Owner"

    conn = post(conn, ~p"/invites/#{token}/accept")
    assert redirected_to(conn) == ~p"/finance?household=#{ctx.household.id}"
    assert Accounts.user_household?(user, ctx.household.id)
  end

  test "declining doesn't join", %{conn: conn} = ctx do
    user = user_fixture()
    {_path, token} = invite(ctx, "someone@example.com")

    conn = conn |> log_in_user(user) |> post(~p"/invites/#{token}/decline")
    assert redirected_to(conn) == ~p"/hub"
    refute Accounts.user_household?(user, ctx.household.id)
  end

  test "a new person signs up from the link and comes back to accept", %{conn: conn} = ctx do
    {path, token} = invite(ctx, "brand-new@example.com")

    conn = get(conn, path)
    html = html_response(conn, 200)
    assert html =~ "Create account"
    assert html =~ "/signup?email=brand-new%40example.com"

    conn = post(conn, ~p"/signup", %{"user" => %{"email" => "brand-new@example.com"}})
    setup_path = redirected_to(conn)
    setup_token = URI.decode_query(URI.parse(setup_path).query)["token"]

    conn =
      post(conn, ~p"/set-password", %{
        "user" => %{"token" => setup_token, "password" => valid_password()}
      })

    assert redirected_to(conn) == path

    conn = post(conn, ~p"/invites/#{token}/accept")
    assert redirected_to(conn) == ~p"/finance?household=#{ctx.household.id}"

    user = Accounts.get_user_by_email("brand-new@example.com")
    assert Accounts.user_household?(user, ctx.household.id)
  end

  test "an existing user signing in returns to the invitation", %{conn: conn} = ctx do
    user = user_fixture(%{email: "member@example.com"})
    {path, _token} = invite(ctx, "member@example.com")

    conn = get(conn, path)

    conn =
      post(conn, ~p"/login", %{
        "user" => %{"email" => "member@example.com", "password" => valid_password()}
      })

    assert redirected_to(conn) == path
    refute Accounts.user_household?(user, ctx.household.id)
  end

  test "accepting while signed out asks to sign in first", %{conn: conn} = ctx do
    {_path, token} = invite(ctx, "x@example.com")
    conn = post(conn, ~p"/invites/#{token}/accept")
    assert redirected_to(conn) == ~p"/login"
  end

  test "an invalid or used link shows a friendly page", %{conn: conn} = ctx do
    assert conn |> get(~p"/invites/nope") |> html_response(404) =~ "Invitation unavailable"

    user = user_fixture()
    {path, token} = invite(ctx, "y@example.com")
    conn = log_in_user(conn, user)
    post(conn, ~p"/invites/#{token}/decline")

    assert conn |> get(path) |> html_response(404) =~ "already answered"
  end
end
