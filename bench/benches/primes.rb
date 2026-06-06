require_relative "../lib/bench"

def prime?(n)
  d = 2
  while d * d <= n
    return false if n % d == 0
    d += 1
  end
  true
end

def count(lo, hi)
  c = 0
  (lo...hi).each { |n| c += 1 if prime?(n) }
  c
end

bench("primes") { count(2, 30000) }
