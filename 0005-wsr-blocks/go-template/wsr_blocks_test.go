package wsr_blocks_test

import (
	"testing"
	"wsr_blocks"

	"gotest.tools/assert"
)

func TestCompress(t *testing.T) {
	vectors := []wsr_blocks.VectorUncompressed{
		wsr_blocks.VectorUint64([]uint64{}),
		wsr_blocks.VectorUint64([]uint64{42, 102, 42, 42, 87, 1 << 11}),
		wsr_blocks.VectorString([]string{"foo", "bar", "bar", "quux"}),
	}

	for _, vector := range vectors {
		for _, compression := range wsr_blocks.Compressions() {
			compressed, ok := wsr_blocks.Compressed(vector, compression)
			if ok {
				decompressed := wsr_blocks.Decompressed(compressed)
				assert.DeepEqual(t, vector, decompressed)
			}
		}
	}
}
