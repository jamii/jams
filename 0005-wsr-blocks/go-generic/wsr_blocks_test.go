package wsr_blocks_test

import (
	"math/rand"
	"testing"
	"wsr_blocks"

	"golang.org/x/exp/constraints"
	"gotest.tools/assert"
)

func TestCompress(t *testing.T) {
	vectors := []wsr_blocks.VectorUncompressed{
		wsr_blocks.VectorFromValues([]uint64{}),
		wsr_blocks.VectorFromValues([]uint64{42, 102, 42, 42, 87, 1 << 11}),
		wsr_blocks.VectorFromValues([]string{"foo", "bar", "bar", "quux"}),
	}

	for _, vector := range vectors {
		for _, compression := range wsr_blocks.Compressions() {
			compressed, ok := wsr_blocks.Compressed(vector, compression)
			if ok {
				decompressed := compressed.Decompressed()
				assert.DeepEqual(t, vector, decompressed)
			}
		}
	}
}

type ValueInt int

type Compare[Elem any] interface {
	IsLess(a Elem) bool
}

func (a ValueInt) IsLess(b ValueInt) bool {
	return a < b
}

func VectorMax(elems []ValueInt) ValueInt {
	var elemMax = elems[0]
	for _, elem := range elems {
		if elemMax.IsLess(elem) {
			elemMax = elem
		}
	}
	return elemMax
}

func VectorMax2[Elem Compare[Elem]](elems []Elem) Elem {
	var elemMax = elems[0]
	for _, elem := range elems {
		if elemMax.IsLess(elem) {
			elemMax = elem
		}
	}
	return elemMax
}

type Vector[Elem any] interface {
	Count() int
	Get(i int) Elem
}

type VectorInt []ValueInt

func (vector VectorInt) Count() int {
	return len(vector)
}

func (vector VectorInt) Get(i int) ValueInt {
	return vector[i]
}

func VectorMax3[Elem constraints.Ordered](vector Vector[Elem]) Elem {
	var elemMax = vector.Get(0)
	count := vector.Count()
	for i := 0; i < count; i++ {
		elem := vector.Get(i)
		if elemMax < elem {
			elemMax = elem
		}
	}
	return elemMax
}

func DoBenchmark(b *testing.B, f func([]ValueInt) ValueInt) {
	rand := rand.New(rand.NewSource(42))
	nums := make([]ValueInt, 1<<16)
	for i := range nums {
		nums[i] = ValueInt(rand.Intn(10000))
	}
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = f(nums)
	}
}

func BenchmarkVectorMax(b *testing.B) {
	DoBenchmark(b, VectorMax)
}

func BenchmarkVectorMax2(b *testing.B) {
	DoBenchmark(b, VectorMax2[ValueInt])
}

func BenchmarkVectorMax3(b *testing.B) {
	DoBenchmark(b, func(elems []ValueInt) ValueInt {
		return VectorMax3[ValueInt](VectorInt(elems))
	})
}
