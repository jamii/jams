package main

import (
	"fmt"
	"math/rand"
	"runtime"
	"time"

	"github.com/quagmt/udecimal"
)

type Value interface {
	isValue()
}

type NumberValue struct {
	Val udecimal.Decimal
}

type StringValue struct {
	Val string
}

type TimeValue struct {
	Val time.Time
}

func (v NumberValue) isValue() {}
func (v StringValue) isValue() {}
func (v TimeValue) isValue()   {}

func toDecimal(v Value) udecimal.Decimal {
	if n, ok := v.(NumberValue); ok {
		return n.Val
	} else {
		d, _ := udecimal.NewFromInt64(0, 0)
		return d
	}
}

func add(a Value, b Value) Value {
	return NumberValue{Val: toDecimal(a).Add(toDecimal(b))}
}

func main() {
	rand.Seed(42)

	stack := make([]Value, 1024)

	var before runtime.MemStats
	runtime.ReadMemStats(&before)

	beforeTime := time.Now()

	for i := 0; i < 10_000_000; i++ {
		switch rand.Intn(len(stack) + 2) {
		case 0:
			d, _ := udecimal.NewFromInt64(rand.Int63n(1000), 0)
			stack = append(stack, NumberValue{Val: d})
		case 1:
			stack = append(stack, StringValue{Val: "Hello"})
		case 2:
			stack = append(stack, TimeValue{Val: time.Now()})
		default:
			a := stack[len(stack)-1]
			stack = stack[:len(stack)-1]
			b := stack[len(stack)-1]
			stack = stack[:len(stack)-1]
			c := add(a, b)
			stack = append(stack, c)
		}
	}

	afterTime := time.Now()

	var after runtime.MemStats
	runtime.ReadMemStats(&after)

	fmt.Printf("Time: %v\n", afterTime.Sub(beforeTime))
	fmt.Printf("Mallocs: %v", after.Mallocs-before.Mallocs)

}
