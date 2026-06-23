import Bench

fib :: Integer -> Integer
fib n = if n < 2 then n else fib (n - 1) + fib (n - 2)

main :: IO ()
main = bench "fib" (\u -> fib (with u 30))
