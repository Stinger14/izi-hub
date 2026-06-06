defmodule Core.Accounts.UsernameGenerator do
  @moduledoc """
  Generates readable usernames in `string-string-string` format.
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

  def generate do
    [pick(@adjectives), pick(@topics), pick(@roles)]
    |> Enum.join("-")
  end

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
