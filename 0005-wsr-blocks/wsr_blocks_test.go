package wsr_blocks_test

import (
	"testing"
	"wsr_blocks"

	"gotest.tools/assert"
)

func TestCompress(t *testing.T) {
	empty := []uint64{}
	ints := []uint64{42, 102, 42, 42, 87, 1 << 11}
	strings := []string{"foo", "bar", "bar", "quux"}

	assert.DeepEqual(
		t,
		wsr_blocks.Compress(wsr_blocks.Dict, empty),
		wsr_blocks.DictCompressedVector{
			Codes:       []uint64{},
			UniqueElems: []uint64{},
		},
	)

	assert.DeepEqual(
		t,
		wsr_blocks.Compress(wsr_blocks.Dict, ints),
		wsr_blocks.DictCompressedVector{
			Codes:       []uint64{0, 1, 0, 0, 2, 3},
			UniqueElems: []uint64{42, 102, 87, 1 << 11},
		},
	)

	assert.DeepEqual(
		t,
		wsr_blocks.Compress(wsr_blocks.Dict, strings),
		wsr_blocks.DictCompressedVector{
			Codes:       []uint64{0, 1, 1, 2},
			UniqueElems: []string{"foo", "bar", "quux"},
		},
	)

	assert.DeepEqual(
		t,
		wsr_blocks.Compress(wsr_blocks.RunLength, empty),
		wsr_blocks.RunLengthCompressedVector{
			Elems: []uint8{},
		},
	)

	assert.DeepEqual(
		t,
		wsr_blocks.Compress(wsr_blocks.RunLength, ints),
		wsr_blocks.RunLengthCompressedVector{
			Elems: []uint16{42, 102, 42, 42, 87, 1 << 11},
		},
	)

	assert.DeepEqual(
		t,
		wsr_blocks.Compress(wsr_blocks.RunLength, []uint64{1 << 63}),
		wsr_blocks.RawCompressedVector{
			Elems: []uint64{1 << 63},
		},
	)
}
