import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
from bench import bench
# sortby: N (key, idx) records ordered by a user key function (key%4096, then key);
# checksum = rolling hash of the idx sequence.
N = 5000
def work():
    x = 1
    data = []
    for i in range(N):
        x = (16807 * x) % 2147483647
        data.append((x, i))
    data.sort(key=lambda r: (r[0] % 4096, r[0]))
    h = 0
    for _, i in data:
        h = (h * 31 + i) % 1000000007
    return h
bench("sortby", work)
