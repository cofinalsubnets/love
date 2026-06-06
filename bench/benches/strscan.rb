require_relative "../lib/bench"

HMOD = 1000000007

# fixed string built once; the timed work is a linear rolling-hash scan.
data = (0...20000).map { |i| (32 + (7 * i) % 95).chr }.join

bench("strscan") do
  h = 0
  data.each_byte { |b| h = (h * 31 + b) % HMOD }
  h
end
