require_relative "../lib/bench"

# mutable hash-table throughput (see bench/benches/hash.l). checksum = N*N.
N = 10000

def work
  h = {}
  N.times { |i| h[97 * i + 1] = i }
  a = 0
  N.times { |i| a += h[97 * i + 1] }
  N.times { |i| k = 97 * i + 1; h[k] += 1 }
  N.times { |i| a += h[97 * i + 1] }
  a
end

bench("hash") { work }
