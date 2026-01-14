for _ <- 1..7 do
  spawn fn ->
    IO.puts "Hello from process #{inspect(self())}"  end
end
