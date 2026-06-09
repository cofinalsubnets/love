Code.require_file("../lib/bench.exs", __DIR__)

# mandelbrot escape counts over a 64x64 grid (see bench/benches/float.l).
defmodule Float64 do
  def mand(cx, cy), do: mand(cx, cy, 0.0, 0.0, 0)
  def mand(cx, cy, zx, zy, it) do
    if it < 100 and zx * zx + zy * zy <= 4.0 do
      mand(cx, cy, zx * zx - zy * zy + cx, 2.0 * zx * zy + cy, it + 1)
    else
      it
    end
  end

  def run do
    Enum.reduce(0..63, 0, fn px, s ->
      Enum.reduce(0..63, s, fn py, s ->
        s + mand(-2.0 + px * 0.046875, -1.5 + py * 0.046875)
      end)
    end)
  end
end

Bench.run("float", fn -> Float64.run() end)
