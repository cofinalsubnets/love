package main

// closure / higher-order stress (see bench/benches/closure.l). checksum = sum 3i.
func twice(f func(int64) int64) func(int64) int64 {
	return func(x int64) int64 { return f(f(x)) }
}

func adder(i int64) func(int64) int64 {
	return func(x int64) int64 { return x + i }
}

const closureN = 100000

func main() {
	bench("closure", func() int64 {
		var s int64
		for i := int64(0); i < closureN; i++ {
			s += twice(adder(i))(i)
		}
		return s
	})
}
