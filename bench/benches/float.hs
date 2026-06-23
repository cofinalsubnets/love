{-# LANGUAGE BangPatterns #-}
import Bench
import Data.List (foldl')

-- mandelbrot escape counts over a 64x64 grid (see bench/benches/float.py).
-- Double IEEE arithmetic, same operation order as the reference.
mand :: Double -> Double -> Int
mand cx cy = go 0.0 0.0 0
  where
    go !zx !zy !it
      | it < 100 && zx * zx + zy * zy <= 4.0 =
          let nzx = zx * zx - zy * zy + cx
              nzy = 2.0 * zx * zy + cy
          in go nzx nzy (it + 1)
      | otherwise = it

work :: [Int] -> Integer
work pxs = foldl' rowAcc 0 pxs
  where
    rowAcc !s px = foldl' (colAcc px) s pxs
    colAcc px !s py =
      s + fromIntegral (mand (-2.0 + fromIntegral px * 0.046875)
                             (-1.5 + fromIntegral py * 0.046875))

main :: IO ()
main = bench "float" (\u -> work (with u [0 .. 63]))
