require_relative "../lib/bench"

HMOD = 1000000007
N = 4000

# build an N-char string by repeated single-char concatenation, then hash it.
bench("strcat") do
  s = ""
  N.times { |i| s += (48 + i % 10).chr }
  h = 0
  s.each_byte { |b| h = (h * 31 + b) % HMOD }
  h
end
