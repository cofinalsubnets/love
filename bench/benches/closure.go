package main

// closures escape into a slice, then applied through it (non-inlinable). checksum = sum 3i.
func twice(f func(int64) int64) func(int64) int64 {
	return func(x int64) int64 { return f(f(x)) }
}
func adder(i int64) func(int64) int64 {
	return func(x int64) int64 { return x + i }
}

const closureN = 100000

func main() {
	bench("closure", func() int64 {
		fns := make([]func(int64) int64, closureN)
		for i := int64(0); i < closureN; i++ {
			fns[i] = twice(adder(i))
		}
		var s int64
		for i := int64(0); i < closureN; i++ {
			s += fns[i](i)
		}
		return s
	})
}
