import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
from bench import bench
# closures escape into a list, then applied through it (non-inlinable). checksum = sum 3i.
twice = lambda f: lambda x: f(f(x))
adder = lambda i: lambda x: x + i
N = 100000
def work():
    fns = [twice(adder(i)) for i in range(N)]
    s = 0
    for i in range(N):
        s += fns[i](i)
    return s
bench("closure", work)
