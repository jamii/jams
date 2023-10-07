package wsr_blocks_test

import (
	"testing"
	"wsr_blocks"

	"gotest.tools/assert"
)

func TestCompress(t *testing.T) {
	vectors := []wsr_blocks.Vector{
		wsr_blocks.VectorFromElems([]uint64{}),
		wsr_blocks.VectorFromElems([]uint64{42, 102, 42, 42, 87, 1 << 11}),
		wsr_blocks.VectorFromElems([]string{"foo", "bar", "bar", "quux"}),
	}

	for _, vector := range vectors {
		for _, compression := range wsr_blocks.Compressions() {
			compressed, ok := vector.Compressed(compression)
			if ok {
				decompressed := compressed.Decompressed()
				vector_raw, _ := vector.AsRaw()
				decompressed_raw, _ := decompressed.AsRaw()
				assert.DeepEqual(t, vector_raw, decompressed_raw)
			}
		}
	}
}
