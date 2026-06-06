defmodule Core.Accounts.UsernameGeneratorTest do
  use ExUnit.Case, async: true

  alias Core.Accounts.UsernameGenerator

  test "generates a stable alias from the same input value" do
    alias_one = UsernameGenerator.generate_from_value("session-123")
    alias_two = UsernameGenerator.generate_from_value("session-123")

    assert alias_one == alias_two
    assert alias_one =~ ~r/^[a-z]+-[a-z]+-[a-z]+$/
  end
end
