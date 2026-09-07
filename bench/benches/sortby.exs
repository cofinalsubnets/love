Code.require_file("../lib/bench.exs", __DIR__)
# sortby: N (key, idx) records ordered by a user comparator on a derived key (key%4096, then key);
# checksum = rolling hash of the idx sequence.
defmodule Sortby do
  def gen_fwd(n) do
    {list, _} = Enum.map_reduce(0..(n - 1), 1, fn i, x ->
      nx = rem(16807 * x, 2147483647)
      {{nx, i}, nx}
    end)
    list
  end
  def less({ka, _}, {kb, _}) do
    ma = rem(ka, 4096); mb = rem(kb, 4096)
    ma < mb or (ma == mb and ka <= kb)
  end
  def hsh(list), do: Enum.reduce(list, 0, fn {_, i}, h -> rem(h * 31 + i, 1000000007) end)
end
Bench.run("sortby", fn -> Sortby.hsh(Enum.sort(Sortby.gen_fwd(5000), &Sortby.less/2)) end)
