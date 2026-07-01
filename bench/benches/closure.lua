package.path = (arg[0]:match("(.*/)") or "./") .. "../lib/?.lua;" .. package.path
local bench = require("bench")
-- closures escape into a table, then applied through it (non-inlinable). checksum = sum 3i.
local function twice(f) return function(x) return f(f(x)) end end
local function adder(i) return function(x) return x + i end end
local N = 100000
bench("closure", function()
  local fns = {}
  for i = 0, N - 1 do fns[i] = twice(adder(i)) end
  local s = 0
  for i = 0, N - 1 do s = s + fns[i](i) end
  return s
end)
