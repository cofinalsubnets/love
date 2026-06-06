-- reverse a 20000-element table each iteration; checksum = new head = 19999.
package.path = (arg[0]:match("(.*/)") or "./") .. "../lib/?.lua;" .. package.path
local bench = require("bench")
local data = {}
for i = 0, 19999 do data[i + 1] = i end
bench("reverse", function()
  local n = #data
  local r = {}
  for i = 1, n do r[i] = data[n - i + 1] end
  return r[1]
end)
