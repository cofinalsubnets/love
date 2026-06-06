require_relative "../lib/bench"

# build the list 1..100000 then sum it.
bench("sum") { (1..100000).to_a.sum }
