Code.require_file("../lib/bench.exs", __DIR__)

# closure / higher-order stress (see bench/benches/closure.l). checksum = sum 3i.
twice = fn f -> fn x -> f.(f.(x)) end end
adder = fn i -> fn x -> x + i end end

Bench.run("closure", fn ->
  Enum.reduce(0..99999, 0, fn i, s -> s + twice.(adder.(i)).(i) end)
end)
