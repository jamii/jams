package main

import (
	"fmt"
	"math/big"
	"math/rand"
	"runtime"
	"time"
	"unsafe"

	"github.com/quagmt/udecimal"
)

type ValueTag uint8

const (
	ValueTagNumber ValueTag = iota
	ValueTagString
	ValueTagTime
)

type Value struct {
	p0    unsafe.Pointer
	p1    unsafe.Pointer
	data0 uint64
	data1 uint64
	data2 uint8
	data3 uint8
	Tag   ValueTag
}

// Must be identical to udecimal.Decimal
type decimal_mirror struct {
	coef bint
	neg  bool
	prec uint8
}
type bint struct {
	bigInt *big.Int
	u128   u128
}
type u128 struct {
	hi uint64
	lo uint64
}

func fromDecimal(d udecimal.Decimal) Value {
	dm := *(*decimal_mirror)(unsafe.Pointer(&d))
	var neg uint8
	if dm.neg {
		neg = 1
	}
	return Value{
		p0:    unsafe.Pointer(dm.coef.bigInt),
		data0: dm.coef.u128.hi,
		data1: dm.coef.u128.lo,
		data2: neg,
		data3: dm.prec,
		Tag:   ValueTagNumber,
	}
}

func toDecimal(v Value) udecimal.Decimal {
	if v.Tag == ValueTagNumber {
		d := decimal_mirror{
			coef: bint{
				bigInt: (*big.Int)(v.p0),
				u128: u128{
					hi: v.data0,
					lo: v.data1,
				},
			},
			neg:  v.data2 != 0,
			prec: v.data3,
		}
		return *(*udecimal.Decimal)(unsafe.Pointer(&d))
	} else {
		d, _ := udecimal.NewFromInt64(0, 0)
		return d
	}
}

func fromString(s string) Value {
	return Value{
		p0:    unsafe.Pointer(unsafe.StringData(s)),
		data0: uint64(len(s)),
		Tag:   ValueTagString,
	}
}

// Must be identical to time.Time
type time_mirror struct {
	wall uint64
	ext  int64
	loc  *time.Location
}

func fromTime(t time.Time) Value {
	tm := *(*time_mirror)(unsafe.Pointer(&t))
	return Value{
		p0:    unsafe.Pointer(tm.loc),
		data0: tm.wall,
		data1: uint64(tm.ext),
		Tag:   ValueTagTime,
	}
}

func add(a Value, b Value) Value {
	return fromDecimal(toDecimal(a).Add(toDecimal(b)))
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
			stack = append(stack, fromDecimal(d))
		case 1:
			stack = append(stack, fromString("Hello"))
		case 2:
			stack = append(stack, fromTime(time.Now()))
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
