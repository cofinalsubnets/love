# elixir benchmark harness -- mirrors bench/bench.l.
# Bench.run(name, work) auto-scales the repetition count (doubling until the run
# clears @min_ms), then times that count ONCE MORE and reports the second run --
# the scaling runs pay the fixed per-process costs (JIT warm-up, the heap's first
# growth), which otherwise ride on whichever power of two the doubling landed on.
# one line per bench, matching the other harnesses:
#     <name> <lang> <reps> <ms> <checksum>
# work is a 0-arity fun returning a deterministic checksum. the column label
# comes from BENCH_LANG (default "elixir").
defmodule Bench do
  @min_ms 200.0
  @lang System.get_env("BENCH_LANG") || "elixir"

  def run(name, work), do: loop(name, work, 1)

  defp loop(name, work, reps) do
    {ms, _chk} = window(work, reps)
    if ms >= @min_ms do
      {ms, chk} = window(work, reps)                  # warm
      IO.puts("#{name} #{@lang} #{reps} #{:erlang.float_to_binary(ms, decimals: 3)} #{chk}")
    else
      loop(name, work, reps * 2)
    end
  end

  defp window(work, reps) do
    t0 = System.monotonic_time(:nanosecond)
    chk = rep(work, reps, nil)
    {(System.monotonic_time(:nanosecond) - t0) / 1.0e6, chk}
  end

  defp rep(_work, 0, chk), do: chk
  defp rep(work, n, _), do: rep(work, n - 1, work.())
end
