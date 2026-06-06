# ruby benchmark harness -- mirrors bench/bench.g.
# bench(name) { work } auto-scales the repetition count (doubling until the run
# clears MIN_MS), then prints one line matching the gwen/python harnesses:
#     <name> ruby <reps> <ms> <checksum>
MIN_MS = 200.0

def bench(name)
  reps = 1
  loop do
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    chk = nil
    reps.times { chk = yield }
    ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000.0
    if ms >= MIN_MS
      puts format("%s ruby %d %.3f %s", name, reps, ms, chk)
      break
    end
    reps *= 2
  end
end
