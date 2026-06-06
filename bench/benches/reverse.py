import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
from bench import bench

data = list(range(20000))

# reverse the list and return its new head (= 19999).
def work():
    return list(reversed(data))[0]

bench("reverse", work)
