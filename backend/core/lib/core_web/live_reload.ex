defmodule CoreWeb.LiveReload do
  @moduledoc """
  Turns a burst of change messages into one reload.

  Context: Finance, Office and hub LiveViews call `drain/1` first in their
  change `handle_info`, dropping queued duplicates so the reload covers them
  all, with no timer.

  ## Example

      def handle_info({:finance_changed, _}, socket) do
        LiveReload.drain(:finance_changed)
        {:noreply, assign_finance_data(socket)}
      end
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
