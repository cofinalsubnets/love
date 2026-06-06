require_relative "../lib/bench"

# Bell numbers in base 36 (a faithful port of ~/bell.rb's memoized lambdas, with
# fresh caches per rep). checksum = total characters across all rendered lines.
DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"
BASE = DIGITS.length

def bell_run(limit)
  facts = {}
  bells = {}
  fact = ->(n) { facts.fetch(n) { x = 1; m = n; (x *= m; m -= 1) while m > 1; facts[n] = x } }
  choose = ->(n, k) { fact[n] / (fact[k] * fact[n - k]) }
  bell = ->(n) { bells.fetch(n) { bells[n] = n < 2 ? 1 : (0...n).reduce(0) { |a, k| a + choose[n - 1, k] * bell[k] } } }
  show = ->(n) { s = +""; (s.prepend(DIGITS[n % BASE]); n /= BASE) while n > 0; s }

  total = 0
  i = 0
  loop do
    b = show[bell[i]]
    return total if b.length > limit
    total += b.length
    i += 1
  end
end

bench("bell") { bell_run(280) }
