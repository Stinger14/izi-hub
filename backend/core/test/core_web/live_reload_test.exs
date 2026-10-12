defmodule CoreWeb.LiveReloadTest do
  use ExUnit.Case, async: true

  alias CoreWeb.LiveReload

  test "drain/1 discards queued messages with the tag and keeps the rest" do
    for n <- 1..5, do: send(self(), {:finance_changed, n})
    send(self(), {:office_changed, :kept})

    assert LiveReload.drain(:finance_changed) == :ok
    refute_received {:finance_changed, _}
    assert_received {:office_changed, :kept}
  end
end
