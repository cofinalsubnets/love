require_relative "../lib/bench"

data = (0...10000).to_a

# square every element, keep the even squares, sum them.
bench("mapfilter") { data.map { |x| x * x }.select { |x| x.even? }.sum }
