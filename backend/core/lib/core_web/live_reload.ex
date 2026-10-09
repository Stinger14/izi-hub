defmodule CoreWeb.LiveReload do
  @moduledoc """
  Coalesces bursts of PubSub change notifications into a single reload.

  LiveViews call `drain/1` at the top of their `handle_info` for a change
  message (e.g. `{:finance_changed, _}`): it discards any more messages with
  the same tag already waiting in the mailbox, so the reload that follows
  covers all of them. A burst that arrives while a reload is running queues
  up and is absorbed by the next one — at most one reload per busy period,
  with no timer and no added latency.
  """

  @doc "Removes queued `{tag, _}` messages from the current process mailbox."
  def drain(tag) when is_atom(tag) do
    receive do
      {^tag, _} -> drain(tag)
    after
      0 -> :ok
    end
  end
end
