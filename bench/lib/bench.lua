-- lua benchmark harness -- mirrors bench/bench.g.
-- bench(name, work) auto-scales the repetition count (doubling until the run
-- clears MIN_MS), then prints one line matching the other harnesses:
--     <name> lua <reps> <ms> <checksum>
-- work is a nullary function returning a deterministic checksum. os.clock() is
-- CPU time, which is fine for these single-threaded CPU-bound loops.
local MIN_MS = 200.0

local function bench(name, work)
  local reps = 1
  while true do
    local t0 = os.clock()
    local chk
    for _ = 1, reps do chk = work() end
    local ms = (os.clock() - t0) * 1000.0
    if ms >= MIN_MS then
      print(string.format("%s lua %d %.3f %s", name, reps, ms, tostring(chk)))
      break
    end
    reps = reps * 2
  end
end

return bench
