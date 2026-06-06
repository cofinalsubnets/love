require_relative "../lib/bench"

data = (0...20000).to_a

# reverse the list and return its new head (= 19999).
bench("reverse") { data.reverse[0] }
