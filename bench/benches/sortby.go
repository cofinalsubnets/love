package main

import "sort"

// sortby: N (key, idx) records ordered by a user comparator on a derived key (key%4096, then key);
// checksum = rolling hash of the idx sequence.
const sortbyN = 5000

type rec struct{ k, i int64 }

func main() {
	bench("sortby", func() int64 {
		x := int64(1)
		data := make([]rec, 0, sortbyN)
		for i := 0; i < sortbyN; i++ {
			x = (16807 * x) % 2147483647
			data = append(data, rec{x, int64(i)})
		}
		sort.Slice(data, func(i, j int) bool {
			ma, mb := data[i].k%4096, data[j].k%4096
			return ma < mb || (ma == mb && data[i].k < data[j].k)
		})
		var h int64
		for _, r := range data {
			h = (h*31 + r.i) % 1000000007
		}
		return h
	})
}
