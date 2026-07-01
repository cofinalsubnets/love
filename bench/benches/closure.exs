Code.require_file("../lib/bench.exs", __DIR__)
# closures escape into a list, then applied through it (non-inlinable). checksum = sum 3i.
twice = fn f -> fn x -> f.(f.(x)) end end
adder = fn i -> fn x -> x + i end end
Bench.run("closure", fn ->
  fns = Enum.map(0..99999, fn i -> twice.(adder.(i)) end)
  fns |> Enum.with_index() |> Enum.reduce(0, fn {f, i}, s -> s + f.(i) end)
end)
