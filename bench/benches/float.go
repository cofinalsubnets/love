package main

// mandelbrot escape counts over a 64x64 grid (see bench/benches/float.l).
func mand(cx, cy float64) int64 {
	zx := 0.0
	zy := 0.0
	var it int64
	for it < 100 && zx*zx+zy*zy <= 4.0 {
		nzx := zx*zx - zy*zy + cx
		nzy := 2.0*zx*zy + cy
		zx = nzx
		zy = nzy
		it++
	}
	return it
}

func main() {
	bench("float", func() int64 {
		var s int64
		for px := 0; px < 64; px++ {
			for py := 0; py < 64; py++ {
				s += mand(-2.0+float64(px)*0.046875, -1.5+float64(py)*0.046875)
			}
		}
		return s
	})
}
