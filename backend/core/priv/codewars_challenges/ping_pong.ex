defmodule PingPong do
  def ping_pong do
    parent = self()
    child =
      spawn(fn ->
        receive do
          :ping -> send(parent, :pong)
        end
      end)

    send(child, :ping)

    receive do
      :pong -> IO.puts("Pong received!")
    end
  end
end
