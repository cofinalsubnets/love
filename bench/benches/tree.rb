require_relative "../lib/bench"

# binary-trees allocation/GC stress (see bench/benches/tree.l). checksum = 2^D-1.
def mk(d) = d == 0 ? nil : [mk(d - 1), mk(d - 1)]
def ck(t) = t.nil? ? 0 : 1 + ck(t[0]) + ck(t[1])

bench("tree") { ck(mk(16)) }
