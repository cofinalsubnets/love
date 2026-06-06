-- list pipeline: square every element, keep the even results, sum them.
package.path = (arg[0]:match("(.*/)") or "./") .. "../lib/?.lua;" .. package.path
local bench = require("bench")
local data = {}
for i = 0, 9999 do data[i + 1] = i end
bench("mapfilter", function()
  local s = 0
  for i = 1, #data do
    local y = data[i] * data[i]
    if y % 2 == 0 then s = s + y end
  end
  return s
end)
