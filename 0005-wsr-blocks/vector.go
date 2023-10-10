package wsr_blocks

import (
	"github.com/RoaringBitmap/roaring"
)

type VectorUncompressedInt interface {
	is_vector_uncompressed_int()

	SizeCompressed() (VectorSize, bool)
}

type VectorUncompressed interface {
	is_vector_uncompressed()

	DictCompressed() (VectorDict, bool)
	BiasCompressed() (VectorBias, bool)
}

type VectorCompressed interface {
	is_vector_compressed()

	Decompressed() VectorUncompressed
}

type Vector interface {
	is_vector()
	zeroedVectorWithCount(count int) VectorUncompressed

	Count() int
}

type VectorUint8 []uint8
type VectorUint16 []uint16
type VectorUint32 []uint32
type VectorUint64 []uint64
type VectorString []string

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

func (_ VectorUint8) is_vector_uncompressed_int()  {}
func (_ VectorUint16) is_vector_uncompressed_int() {}
func (_ VectorUint32) is_vector_uncompressed_int() {}
func (_ VectorUint64) is_vector_uncompressed_int() {}

func (_ VectorUint8) is_vector_uncompressed()  {}
func (_ VectorUint16) is_vector_uncompressed() {}
func (_ VectorUint32) is_vector_uncompressed() {}
func (_ VectorUint64) is_vector_uncompressed() {}
func (_ VectorString) is_vector_uncompressed() {}

func (_ VectorDict) is_vector_compressed() {}
func (_ VectorSize) is_vector_compressed() {}
func (_ VectorBias) is_vector_compressed() {}

func (_ VectorUint8) is_vector()  {}
func (_ VectorUint16) is_vector() {}
func (_ VectorUint32) is_vector() {}
func (_ VectorUint64) is_vector() {}
func (_ VectorString) is_vector() {}
func (_ VectorDict) is_vector()   {}
func (_ VectorSize) is_vector()   {}
func (_ VectorBias) is_vector()   {}

func VectorFromValues(values interface{}) VectorUncompressed {
	switch values.(type) {
	case []uint8:
		return VectorUint8(values.([]uint8))
	case []uint16:
		return VectorUint16(values.([]uint16))
	case []uint32:
		return VectorUint32(values.([]uint32))
	case []uint64:
		return VectorUint64(values.([]uint64))
	case []string:
		return VectorString(values.([]string))
	default:
		panic("Unsupported value type")
	}
}

func (vector VectorUint8) Count() int {
	return len(vector)
}
func (vector VectorUint16) Count() int {
	return len(vector)
}
func (vector VectorUint32) Count() int {
	return len(vector)
}
func (vector VectorUint64) Count() int {
	return len(vector)
}
func (vector VectorString) Count() int {
	return len(vector)
}
func (vector VectorDict) Count() int {
	return vector.codes.Count()
}
func (vector VectorSize) Count() int {
	return vector.values.Count()
}
func (vector VectorBias) Count() int {
	return vector.count
}

func zeroedVector(vector Vector) VectorUncompressed {
	return vector.zeroedVectorWithCount(vector.Count())
}

func (vector VectorUint8) zeroedVectorWithCount(count int) VectorUncompressed {
	return VectorUint8(make([]uint8, count))
}
func (vector VectorUint16) zeroedVectorWithCount(count int) VectorUncompressed {
	return VectorUint16(make([]uint16, count))
}
func (vector VectorUint32) zeroedVectorWithCount(count int) VectorUncompressed {
	return VectorUint32(make([]uint32, count))
}
func (vector VectorUint64) zeroedVectorWithCount(count int) VectorUncompressed {
	return VectorUint64(make([]uint64, count))
}
func (vector VectorString) zeroedVectorWithCount(count int) VectorUncompressed {
	return VectorString(make([]string, count))
}
func (vector VectorDict) zeroedVectorWithCount(count int) VectorUncompressed {
	return vector.uniqueValues.zeroedVectorWithCount(count)
}
func (vector VectorSize) zeroedVectorWithCount(count int) VectorUncompressed {
	switch vector.originalSizeBits {
	case 8:
		return VectorUint8(make([]uint8, count))
	case 16:
		return VectorUint16(make([]uint16, count))
	case 32:
		return VectorUint32(make([]uint32, count))
	case 64:
		return VectorUint64(make([]uint64, count))
	default:
		panic("Unreachable")
	}
}
func (vector VectorBias) zeroedVectorWithCount(count int) VectorUncompressed {
	return vector.remainder.zeroedVectorWithCount(count)
}
