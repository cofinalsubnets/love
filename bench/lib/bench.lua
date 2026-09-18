-- lua benchmark harness -- mirrors bench/bench.l.
-- bench(name, work) auto-scales the repetition count (doubling until the run
-- clears MIN_MS), then times that count ONCE MORE and reports the second run --
-- the scaling runs pay the fixed per-process costs (JIT warm-up, the heap's first
-- growth), which otherwise ride on whichever power of two the doubling landed on.
-- one line per bench, matching the other harnesses:
--     <name> <lang> <reps> <ms> <checksum>
-- work is a nullary function returning a deterministic checksum. os.clock() is
-- CPU time, which is fine for these single-threaded CPU-bound loops. the
-- language label comes from BENCH_LANG (so lua and luajit share these files).
local MIN_MS = 200.0
local LANG = os.getenv("BENCH_LANG") or "lua"

local function run(work, reps)
  local t0 = os.clock()
  local chk
  for _ = 1, reps do chk = work() end
  return (os.clock() - t0) * 1000.0, chk
end

local function bench(name, work)
  local reps = 1
  while true do
    local ms, chk = run(work, reps)
    if ms >= MIN_MS then
      ms, chk = run(work, reps)                 -- warm
      print(string.format("%s %s %d %.3f %s", name, LANG, reps, ms, tostring(chk)))
      break
    end
    reps = reps * 2
  end
end

return bench
