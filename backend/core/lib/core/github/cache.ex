defmodule Core.GitHub.Cache do
  @moduledoc """
  	Simple GenServer to own GitHub's stats ETS table.
  """
  use GenServer

  @table __MODULE__

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def table, do: @table

  @impl true
  def init(:ok) do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [
          :named_table,
          :public,
          :set,
          read_concurrency: true,
          write_concurrency: true
        ])

      _ ->
        :ok
    end

    {:ok, %{}}
  end
end
