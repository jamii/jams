package wsr_blocks

import (
	"github.com/RoaringBitmap/roaring"
)

type BoxedValue interface {
	is_boxed_value()
}

type VectorUncompressedInt interface {
	is_vector_uncompressed_int()
}

type VectorUncompressed interface {
	is_vector_uncompressed()
}

type VectorCompressed interface {
	is_vector_compressed()
}

type Vector interface {
	is_vector()
	zeroedVectorWithCount(count int) VectorUncompressed

	Count() int
}

type VectorDict struct {
	codes        Vector
	uniqueValues Vector
}

type VectorSize struct {
	originalSizeBits uint8
	values           Vector
}

type VectorBias struct {
	count     int
	value     BoxedValue
	presence  roaring.Bitmap
	remainder Vector
}

type Compression = struct {
	tag compressionTag
}
type compressionTag = uint64

const (
	Dict compressionTag = iota
	Size
	Bias
)

func ensureDecompressed(vector Vector) VectorUncompressed {
	switch vector.(type) {
	case VectorUncompressed:
		return vector.(VectorUncompressed)
	case VectorCompressed:
		return Decompressed(vector.(VectorCompressed))
	default:
		panic("Unreachable")
	}
}
