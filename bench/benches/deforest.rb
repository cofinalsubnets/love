require_relative "../lib/bench"

# map/filter/fold list pipeline: sum the squares of the odd numbers in [0, N).
# the range + intermediate arrays are built INSIDE the timed work. checksum = 1333333330000.
bench("deforest") { (0...20000).select(&:odd?).map { |x| x * x }.sum }
