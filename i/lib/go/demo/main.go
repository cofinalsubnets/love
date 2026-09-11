package main

import (
	"fmt"
	"math"
	"time"

	"love/love"
)

func main() {
	t0 := time.Now()
	l, err := love.Open()
	if err != nil {
		panic(err)
	}
	defer l.Close()
	fmt.Printf("open        %v\n", time.Since(t0).Round(time.Millisecond))

	must(l.Eval("+[1 2 3 4]"))
	fmt.Printf("net         %d  (type %d)\n", l.ToInt(0), l.TypeAt(0))
	l.Pop(1)

	must(l.Eval(`("hello " + "world")`))
	fmt.Printf("string      %s\n", l.String(0))
	l.Pop(1)

	must(l.Eval("(map (+ 1) [1 2 3])"))
	var v []int
	for i := 0; i < l.Count(0); i++ {
		l.At(0, i)
		v = append(v, l.ToInt(0))
		l.Pop(1)
	}
	fmt.Printf("list        %v\n", v)
	l.Pop(1)

	must(l.Eval(`(a \ b \ a * a + b)`))
	l.Dup(0)
	l.PushInt(7)
	l.PushInt(5)
	must(l.Apply(2))
	fmt.Printf("apply       %d\n", l.ToInt(0))
	l.Pop(1)

	const n = 20000
	t := time.Now()
	for i := 0; i < n; i++ {
		l.Dup(0)
		l.PushInt(7)
		l.PushInt(5)
		must(l.Apply(2))
		l.Pop(1)
	}
	fmt.Printf("apply cost  %.2f us/call\n", float64(time.Since(t).Nanoseconds())/n/1e3)
	l.Pop(1)

	must(l.Defn("hypot", 2, func(l *love.Lv, _ int) error {
		a, b := l.ToFlo(0), l.ToFlo(1)
		l.PushFlo(math.Sqrt(a*a + b*b))
		return nil
	}))
	must(l.Eval("(hypot 3.0 4.0)"))
	fmt.Printf("callback    %g\n", l.ToFlo(0))
	l.Pop(1)

	// the same loop, but every call crosses back into Go
	must(l.Eval("hypot"))
	t = time.Now()
	for i := 0; i < n; i++ {
		l.Dup(0)
		l.PushFlo(3)
		l.PushFlo(4)
		must(l.Apply(2))
		l.Pop(1)
	}
	fmt.Printf("cb cost     %.2f us/call\n", float64(time.Since(t).Nanoseconds())/n/1e3)
	l.Pop(1)

	if err := l.Eval("(scare 'boom 42)"); err != nil {
		fmt.Printf("scare       %v\n", err)
	}
	fmt.Printf("after scare depth %d, ok=%v\n", l.Top(), l.OK())
}

func must(err error) {
	if err != nil {
		panic(err)
	}
}
