-- mandelbrot escape counts over a 64x64 grid (see bench/benches/float.l).
package.path = (arg[0]:match("(.*/)") or "./") .. "../lib/?.lua;" .. package.path
local bench = require("bench")
local function mand(cx, cy)
  local zx, zy, it = 0.0, 0.0, 0
  while it < 100 and zx * zx + zy * zy <= 4.0 do
    local nzx = zx * zx - zy * zy + cx
    local nzy = 2.0 * zx * zy + cy
    zx = nzx; zy = nzy; it = it + 1
  end
  return it
end
bench("float", function()
  local s = 0
  for px = 0, 63 do
    for py = 0, 63 do
      s = s + mand(-2.0 + px * 0.046875, -1.5 + py * 0.046875)
    end
  end
  return s
end)
