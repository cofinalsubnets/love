package main

// list pipeline: square every element, keep the even results, sum them.
var mapfilterData = func() []int64 {
	d := make([]int64, 10000)
	for i := range d {
		d[i] = int64(i)
	}
	return d
}()

func main() {
	bench("mapfilter", func() int64 {
		mapped := make([]int64, len(mapfilterData))
		for i, v := range mapfilterData {
			mapped[i] = v * v
		}
		filtered := make([]int64, 0, len(mapped))
		for _, v := range mapped {
			if v%2 == 0 {
				filtered = append(filtered, v)
			}
		}
		var s int64
		for _, v := range filtered {
			s += v
		}
		return s
	})
}
