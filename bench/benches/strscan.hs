{-# LANGUAGE BangPatterns #-}
import Bench
import Data.List (foldl')
import Data.Char (chr, ord)

-- fixed string built once; the timed work is a linear rolling-hash scan.
-- checksum = 219660688.
hmod :: Integer
hmod = 1000000007

dat :: String
dat = [ chr (32 + (7 * i) `mod` 95) | i <- [0 .. 19999] ]

scan :: String -> Integer
scan = foldl' (\ !h ch -> (h * 31 + fromIntegral (ord ch)) `mod` hmod) 0

-- `dat` is a shared CAF (built once, as in the reference); pinning it through
-- `with` (the rep loop's argument) keeps the timed scan inside the lambda so it
-- re-runs every rep instead of being floated out and shared as a single result.
main :: IO ()
main = bench "strscan" (\u -> scan (with u dat))
