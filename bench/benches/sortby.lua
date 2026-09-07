-- sortby: N (key, idx) records ordered by a user comparator on a derived key (key%4096, then key);
-- checksum = rolling hash of the idx sequence.
package.path = (arg[0]:match("(.*/)") or "./") .. "../lib/?.lua;" .. package.path
local bench = require("bench")
local N = 5000
bench("sortby", function()
  local x = 1
  local data = {}
  for i = 1, N do x = (16807 * x) % 2147483647; data[i] = {x, i - 1} end
  table.sort(data, function(a, b)
    local ma, mb = a[1] % 4096, b[1] % 4096
    if ma ~= mb then return ma < mb end
    return a[1] < b[1]
  end)
  local h = 0
  for i = 1, N do h = (h * 31 + data[i][2]) % 1000000007 end
  return h
end)
