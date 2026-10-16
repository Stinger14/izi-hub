defmodule Core.Accounts.UsernameGenerator do
  @moduledoc """
  Readable random usernames like `bright-elixir-builder`.

  Context: used when an account is created from just an email.

  ## Example

      UsernameGenerator.generate()
      #=> "agile-phoenix-maker"
  """

  @adjectives ~w(
    agile
    bright
    calm
    clever
    eager
    gentle
    noble
    quiet
    steady
    swift
    vivid
    wise
  )

  @topics ~w(
    cloud
    code
    craft
    data
    logic
    pixel
    prism
    river
    signal
    stack
    story
    vector
  )

  @roles ~w(
    builder
    creator
    engineer
    maker
    navigator
    thinker
    writer
    artisan
    designer
    explorer
    mentor
    planner
  )

  @doc "A random `adjective-topic-role` username."
  def generate do
    [pick(@adjectives), pick(@topics), pick(@roles)]
    |> Enum.join("-")
  end

  @doc """
  A stable `adjective-topic-role` username picked from a hash of `value` (same
  input, same name).
  """
  def generate_from_value(value) do
    [
      pick_by_hash(@adjectives, value, 0),
      pick_by_hash(@topics, value, 1),
      pick_by_hash(@roles, value, 2)
    ]
    |> Enum.join("-")
  end

  defp pick(words), do: Enum.random(words)

  defp pick_by_hash(words, value, salt) do
    index =
      :erlang.phash2({value, salt}, length(words))

    Enum.at(words, index)
  end
end
