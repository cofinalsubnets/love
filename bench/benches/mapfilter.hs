{-# LANGUAGE BangPatterns #-}
import Bench
import Data.List (foldl')

-- square every element of [0..9999], keep the even squares, sum them.
-- checksum = 166616670000. The index source is pinned through `with` (the rep
-- loop's argument) so GHC runs the real O(n) map/filter/fold each rep rather
-- than fold it to a closed form or share it as a CAF.
n :: Int
n = 10000

work :: [Int] -> Integer
work xs = foldl' (\ !a x -> a + x) 0
            [ sq | x <- xs, let sq = fromIntegral x * fromIntegral x :: Integer
                 , even sq ]

main :: IO ()
main = bench "mapfilter" (\u -> work (with u [0 .. n - 1]))
