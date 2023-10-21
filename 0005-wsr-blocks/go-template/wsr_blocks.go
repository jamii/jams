package wsr_blocks

import (
	"github.com/RoaringBitmap/roaring"
)

type BoxedValue interface {
	is_boxed_value()
}

type VectorUncompressed interface {
	is_vector_uncompressed()
}

type VectorCompressed interface {
	is_vector_compressed()
}

type Vector interface {
	is_vector()
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
	switch vector := vector.(type) {
	case VectorUncompressed:
		return vector
	case VectorCompressed:
		return Decompressed(vector)
	default:
		panic("Unreachable")
	}
}
