import Bench

tak :: Integer -> Integer -> Integer -> Integer
tak x y z =
  if y < x
    then tak (tak (x - 1) y z) (tak (y - 1) z x) (tak (z - 1) x y)
    else z

main :: IO ()
main = bench "tak" (\u -> tak (with u 22) (with u 12) (with u 6))
