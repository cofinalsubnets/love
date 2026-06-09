-- closure / higher-order stress (see bench/benches/closure.l). checksum = sum 3i.
package.path = (arg[0]:match("(.*/)") or "./") .. "../lib/?.lua;" .. package.path
local bench = require("bench")
local function twice(f) return function(x) return f(f(x)) end end
local function adder(i) return function(x) return x + i end end
local N = 100000
bench("closure", function()
  local s = 0
  for i = 0, N - 1 do s = s + twice(adder(i))(i) end
  return s
end)
