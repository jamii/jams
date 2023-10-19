package wsr_blocks

import (
	"github.com/RoaringBitmap/roaring"
	"golang.org/x/exp/constraints"
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

	Decompressed() VectorUncompressed
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
		return vector.(VectorCompressed).Decompressed()
	default:
		panic("Unreachable")
	}
}

func (vector VectorDict) Decompressed() VectorUncompressed {
	result := zeroedVector(vector)
	dictDecompress1(ensureDecompressed(vector.uniqueValues), ensureDecompressed(vector.codes), result)
	return result
}

func dictDecompress1(uniqueValues VectorUncompressed, codes VectorUncompressed, to VectorUncompressed) {
	codes_uint64 := []uint64(codes.(VectorUint64))
	switch uniqueValues.(type) {
	case VectorUint8:
		dictDecompress2([]uint8(uniqueValues.(VectorUint8)), codes_uint64, []uint8(to.(VectorUint8)))
	case VectorUint16:
		dictDecompress2([]uint16(uniqueValues.(VectorUint16)), codes_uint64, []uint16(to.(VectorUint16)))
	case VectorUint32:
		dictDecompress2([]uint32(uniqueValues.(VectorUint32)), codes_uint64, []uint32(to.(VectorUint32)))
	case VectorUint64:
		dictDecompress2([]uint64(uniqueValues.(VectorUint64)), codes_uint64, []uint64(to.(VectorUint64)))
	case VectorString:
		dictDecompress2([]string(uniqueValues.(VectorString)), codes_uint64, []string(to.(VectorString)))
	}
}

func dictDecompress2[Value any, Code constraints.Integer](uniqueValues []Value, codes []Code, to []Value) {
	for i := range to {
		to[i] = uniqueValues[codes[i]]
	}
}

func (vector VectorSize) Decompressed() VectorUncompressed {
	result := zeroedVector(vector)
	sizeDecompress1(ensureDecompressed(vector.values), result)
	return result
}

func sizeDecompress1(from interface{}, to interface{}) {
	switch from.(type) {
	case VectorUint8:
		sizeDecompress2([]uint8(from.(VectorUint8)), to)
	case VectorUint16:
		sizeDecompress2([]uint16(from.(VectorUint16)), to)
	case VectorUint32:
		sizeDecompress2([]uint32(from.(VectorUint32)), to)
	case VectorUint64:
		sizeDecompress2([]uint64(from.(VectorUint64)), to)
	}
}

func sizeDecompress2[From constraints.Integer](from []From, to interface{}) {
	switch to.(type) {
	case VectorUint8:
		sizeDecompress3(from, []uint8(to.(VectorUint8)))
	case VectorUint16:
		sizeDecompress3(from, []uint16(to.(VectorUint16)))
	case VectorUint32:
		sizeDecompress3(from, []uint32(to.(VectorUint32)))
	case VectorUint64:
		sizeDecompress3(from, []uint64(to.(VectorUint64)))
	}
}

func sizeDecompress3[From constraints.Integer, To constraints.Integer](from []From, to []To) {
	for i := range from {
		to[i] = To(from[i])
	}
}

func (vector VectorBias) Decompressed() VectorUncompressed {
	result := zeroedVector(vector)
	biasDecompress1(vector.value, vector.presence, ensureDecompressed(vector.remainder), result)
	return result
}

func biasDecompress1(value interface{}, presence roaring.Bitmap, remainder interface{}, to interface{}) {
	switch remainder.(type) {
	case VectorUint8:
		biasDecompress2(uint8(value.(BoxedValueUint8)), presence, []uint8(remainder.(VectorUint8)), []uint8(to.(VectorUint8)))
	case VectorUint16:
		biasDecompress2(uint16(value.(BoxedValueUint16)), presence, []uint16(remainder.(VectorUint16)), []uint16(to.(VectorUint16)))
	case VectorUint32:
		biasDecompress2(uint32(value.(BoxedValueUint32)), presence, []uint32(remainder.(VectorUint32)), []uint32(to.(VectorUint32)))
	case VectorUint64:
		biasDecompress2(uint64(value.(BoxedValueUint64)), presence, []uint64(remainder.(VectorUint64)), []uint64(to.(VectorUint64)))
	case VectorString:
		biasDecompress2(string(value.(BoxedValueString)), presence, []string(remainder.(VectorString)), []string(to.(VectorString)))
	}
}

func biasDecompress2[Value comparable](value Value, presence roaring.Bitmap, remainder []Value, to []Value) {
	var remainder_index int = 0
	for i := range to {
		if presence.ContainsInt(i) {
			to[i] = value
		} else {
			to[i] = remainder[remainder_index]
			remainder_index++
		}
	}
}

// TODO remove below functions

func BoxedValueFromValue(value interface{}) BoxedValue {
	switch value.(type) {
	case uint8:
		return BoxedValueUint8(value.(uint8))
	case uint16:
		return BoxedValueUint16(value.(uint16))
	case uint32:
		return BoxedValueUint32(value.(uint32))
	case uint64:
		return BoxedValueUint64(value.(uint64))
	case string:
		return BoxedValueString(value.(string))
	default:
		panic("Unreachable")
	}
}

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
