# python benchmark harness -- mirrors bench/bench.l.
# bench(name, work) auto-scales the repetition count (doubling until the run
# clears MIN_MS), then times that count ONCE MORE and reports the second run --
# the scaling runs pay the fixed per-process costs (JIT warm-up, the heap's first
# growth), which otherwise ride on whichever power of two the doubling landed on.
# one line per bench, matching the other harnesses:
#     <name> <lang> <reps> <ms> <checksum>
# the same file serves cpython, pypy, and hy (which imports it); BENCH_LANG sets
# the label so the columns stay distinct, default "python".
import os, time

MIN_MS = 200.0
LANG = os.environ.get("BENCH_LANG", "python")

def _run(work, reps):
    t0 = time.perf_counter()
    chk = None
    for _ in range(reps):
        chk = work()
    return (time.perf_counter() - t0) * 1000.0, chk

def bench(name, work):
    reps = 1
    while True:
        ms, chk = _run(work, reps)
        if ms >= MIN_MS:
            ms, chk = _run(work, reps)          # warm
            break
        reps *= 2
    print(f"{name} {LANG} {reps} {ms:.3f} {chk}")
