Code.require_file("../lib/bench.exs", __DIR__)

# map/filter/fold list pipeline: sum the squares of the odd numbers in [0, N).
# the range + intermediate lists are built INSIDE the timed work. checksum = 1333333330000.
Bench.run("polysum", fn ->
  0..19999
  |> Enum.filter(&(rem(&1, 2) == 1))
  |> Enum.map(&(&1 * &1))
  |> Enum.sum()
end)
