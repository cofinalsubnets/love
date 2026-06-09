import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
from bench import bench

# mandelbrot escape counts over a 64x64 grid (see bench/benches/float.l).
def mand(cx, cy):
    zx = 0.0
    zy = 0.0
    it = 0
    while it < 100 and zx * zx + zy * zy <= 4.0:
        nzx = zx * zx - zy * zy + cx
        nzy = 2.0 * zx * zy + cy
        zx = nzx
        zy = nzy
        it += 1
    return it

def work():
    s = 0
    for px in range(64):
        for py in range(64):
            s += mand(-2.0 + px * 0.046875, -1.5 + py * 0.046875)
    return s

bench("float", work)
