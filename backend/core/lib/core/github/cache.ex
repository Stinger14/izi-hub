defmodule Core.GitHub.Cache do
  @moduledoc """
  Owns the ETS table where `Core.GitHub` caches API results for five minutes.

  Context: started by the application supervisor. Tests seed it directly to
  avoid network calls.
  """
  use GenServer

  @table __MODULE__

  @doc "Starts the cache owner process."
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc "The ETS table name."
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
