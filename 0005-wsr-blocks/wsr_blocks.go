package wsr_blocks

import (
	"golang.org/x/exp/constraints"
)

func Sum64(nums []int64) int64 {
	var total int64 = 0
	for _, num := range nums {
		total += num
	}
	return total
}

func Sum64Indirect(nums []int64) int64 {
	var total int64 = 0
	for _, num := range nums {
		total = Add[int64]{}.operate(total, num)
	}
	return total
}

func SumGeneric[Num constraints.Integer](nums []Num) Num {
	var total Num = 0
	for _, num := range nums {
		total = Add[Num]{}.operate(total, num)
	}
	return total
}

func SumGenericGeneric[Num constraints.Integer, Op Operator[Num]](op Op, nums []Num) Num {
	var total Num = 0
	for _, num := range nums {
		total = op.operate(total, num)
	}
	return total
}

type Operator[Num constraints.Integer] interface {
	operate(a Num, b Num) Num
}

type Add[Num constraints.Integer] struct{}

func (add Add[int64]) operate(a int64, b int64) int64 {
	return a + b
}
