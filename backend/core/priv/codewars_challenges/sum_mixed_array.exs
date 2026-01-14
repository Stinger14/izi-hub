defmodule SumMix do
  def sum_mix(list) do
    list
    |> Enum.map(fn x ->
      if is_integer(x) do
        x
      else
        String.to_integer(x)
      end
    end)
    |> Enum.sum()
  end
end

SumMix.sum_mix("32156")
