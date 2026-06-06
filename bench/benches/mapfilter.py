import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
from bench import bench

data = list(range(10000))

# square every element, keep the even squares, sum them.
def work():
    return sum(filter(lambda x: x % 2 == 0, map(lambda x: x * x, data)))

bench("mapfilter", work)
