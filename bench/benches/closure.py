import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
from bench import bench

# closure / higher-order stress (see bench/benches/closure.l). checksum = sum 3i.
twice = lambda f: lambda x: f(f(x))
adder = lambda i: lambda x: x + i
N = 100000

def work():
    s = 0
    for i in range(N):
        s += twice(adder(i))(i)
    return s

bench("closure", work)
