require_relative "../lib/bench"

# closure / higher-order stress (see bench/benches/closure.l). checksum = sum 3i.
TWICE = ->(f) { ->(x) { f.(f.(x)) } }
ADDER = ->(i) { ->(x) { x + i } }
N = 100000

def work
  s = 0
  N.times { |i| s += TWICE.(ADDER.(i)).(i) }
  s
end

bench("closure") { work }
