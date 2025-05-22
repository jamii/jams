package main

import (
	"fmt"
	"math/rand"
	"runtime"
	"time"

	"github.com/quagmt/udecimal"
)

type ValueTag int64

const (
	ValueTagNumber ValueTag = iota
	ValueTagString
	ValueTagTime
)

type Value struct {
	tag    ValueTag
	number udecimal.Decimal
	string string
	time   time.Time
	//garbage [1024]uint8
	//big_garbage [128 * 1024]uint8
}

func toDecimal(v Value) udecimal.Decimal {
	if v.tag == ValueTagNumber {
		return v.number
	} else {
		d, _ := udecimal.NewFromInt64(0, 0)
		return d
	}
}

func add(a Value, b Value) Value {
	return Value{
		tag:    ValueTagNumber,
		number: toDecimal(a).Add(toDecimal(b)),
	}
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
			stack = append(stack, Value{tag: ValueTagNumber, number: d})
		case 1:
			stack = append(stack, Value{tag: ValueTagString, string: "Hello"})
		case 2:
			stack = append(stack, Value{tag: ValueTagTime, time: time.Now()})
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
	fmt.Printf("Mallocs: %v\n", after.Mallocs-before.Mallocs)

}
