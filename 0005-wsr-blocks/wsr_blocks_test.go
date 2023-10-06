package wsr_blocks_test

import (
	"math/rand"
	"testing"
	"wsr_blocks"
)

func BenchmarkSum64(b *testing.B) {
	rand := rand.New(rand.NewSource(42))
	nums := make([]int64, 1<<16)
	for i := range nums {
		nums[i] = int64(rand.Intn(1000))
	}
	b.ResetTimer()
	var total int64 = 0
	for i := 0; i < b.N; i++ {
		total += wsr_blocks.Sum64(nums)
	}
	if total == 0 {
		panic("Unreachable")
	}
}

func BenchmarkSum64Indirect(b *testing.B) {
	rand := rand.New(rand.NewSource(42))
	nums := make([]int64, 1<<16)
	for i := range nums {
		nums[i] = int64(rand.Intn(1000))
	}
	b.ResetTimer()
	var total int64 = 0
	for i := 0; i < b.N; i++ {
		total += wsr_blocks.Sum64(nums)
	}
	if total == 0 {
		panic("Unreachable")
	}
}

func BenchmarkSumGeneric64(b *testing.B) {
	rand := rand.New(rand.NewSource(42))
	nums := make([]int64, 1<<16)
	for i := range nums {
		nums[i] = int64(rand.Intn(1000))
	}
	b.ResetTimer()
	var total int64 = 0
	for i := 0; i < b.N; i++ {
		total += wsr_blocks.SumGeneric(nums)
	}
	if total == 0 {
		panic("Unreachable")
	}
}

func BenchmarkSumGenericGeneric64(b *testing.B) {
	rand := rand.New(rand.NewSource(42))
	nums := make([]int64, 1<<16)
	for i := range nums {
		nums[i] = int64(rand.Intn(1000))
	}
	b.ResetTimer()
	var total int64 = 0
	for i := 0; i < b.N; i++ {
		total += wsr_blocks.SumGenericGeneric(wsr_blocks.Add[int64]{}, nums)
	}
	if total == 0 {
		panic("Unreachable")
	}
}
