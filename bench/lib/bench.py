# python benchmark harness -- mirrors bench/bench.g.
# bench(name, work) auto-scales the repetition count (doubling until the run
# clears MIN_MS), then prints one line matching the gwen/ruby harnesses:
#     <name> python <reps> <ms> <checksum>
import time

MIN_MS = 200.0

def bench(name, work):
    reps = 1
    while True:
        t0 = time.perf_counter()
        chk = None
        for _ in range(reps):
            chk = work()
        ms = (time.perf_counter() - t0) * 1000.0
        if ms >= MIN_MS:
            break
        reps *= 2
    print(f"{name} python {reps} {ms:.3f} {chk}")
