require_relative "../lib/bench"

# mandelbrot escape counts over a 64x64 grid (see bench/benches/float.l).
def mand(cx, cy)
  zx = 0.0
  zy = 0.0
  it = 0
  while it < 100 && zx * zx + zy * zy <= 4.0
    nzx = zx * zx - zy * zy + cx
    nzy = 2.0 * zx * zy + cy
    zx = nzx
    zy = nzy
    it += 1
  end
  it
end

def work
  s = 0
  64.times { |px| 64.times { |py| s += mand(-2.0 + px * 0.046875, -1.5 + py * 0.046875) } }
  s
end

bench("float") { work }
