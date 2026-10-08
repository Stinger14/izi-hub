defmodule Core.Accounts.GithubUsernameTest do
  use Core.DataCase, async: true

  alias Core.Accounts
  alias Core.Accounts.User

  defp changeset(value),
    do: User.github_username_changeset(%User{}, %{"github_username" => value})

  test "accepts a valid login and strips a leading @ and whitespace" do
    cs = changeset("  @Stinger14 ")
    assert cs.valid?
    assert Ecto.Changeset.get_change(cs, :github_username) == "Stinger14"
  end

  test "accepts single inner hyphens" do
    assert changeset("ghost-1nd-shell").valid?
  end

  test "rejects invalid logins" do
    for bad <- [
          "-leading",
          "trailing-",
          "double--hyphen",
          "has space",
          "under_score",
          String.duplicate("a", 40)
        ] do
      refute changeset(bad).valid?, "expected #{inspect(bad)} to be invalid"
    end
  end

  test "a blank value or bare @ clears the link" do
    user = %User{github_username: "Stinger14"}

    for blank <- ["", "  ", "@"] do
      cs = User.github_username_changeset(user, %{"github_username" => blank})
      assert cs.valid?
      assert Ecto.Changeset.get_field(cs, :github_username) == nil
    end
  end

  test "update_github_username/2 persists the link" do
    {:ok, user} =
      Accounts.register_user(%{
        email: "gh_user_#{System.unique_integer([:positive])}@example.com",
        password: "Password123!",
        username: "gh_user_#{System.unique_integer([:positive])}",
        full_name: "GH User"
      })

    assert {:ok, %User{github_username: "octocat"}} =
             Accounts.update_github_username(user, %{"github_username" => "octocat"})
  end
end
