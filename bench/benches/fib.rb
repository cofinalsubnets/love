require_relative "../lib/bench"

def fib(n) = n < 2 ? n : fib(n - 1) + fib(n - 2)

bench("fib") { fib(30) }
