package wsr_blocks

import (
	"github.com/RoaringBitmap/roaring"
	"golang.org/x/exp/constraints"
)

type BoxedValueUint8 uint8
type BoxedValueUint16 uint16
type BoxedValueUint32 uint32
type BoxedValueUint64 uint64
type BoxedValueString string

type BoxedValue interface {
	is_boxed_value()
}

func (_ BoxedValueUint8) is_boxed_value()  {}
func (_ BoxedValueUint16) is_boxed_value() {}
func (_ BoxedValueUint32) is_boxed_value() {}
func (_ BoxedValueUint64) is_boxed_value() {}
func (_ BoxedValueString) is_boxed_value() {}

type VectorUint8 []uint8
type VectorUint16 []uint16
type VectorUint32 []uint32
type VectorUint64 []uint64
type VectorString []string

type VectorUncompressedInt interface {
	is_vector_uncompressed_int()

	sizeCompressed1() (VectorSize, bool)
}

func (_ VectorUint8) is_vector_uncompressed_int()  {}
func (_ VectorUint16) is_vector_uncompressed_int() {}
func (_ VectorUint32) is_vector_uncompressed_int() {}
func (_ VectorUint64) is_vector_uncompressed_int() {}

type VectorUncompressed interface {
	is_vector_uncompressed()

	dictCompressed1() (VectorDict, bool)
	biasCompressed1() (VectorBias, bool)
}

func (_ VectorUint8) is_vector_uncompressed()  {}
func (_ VectorUint16) is_vector_uncompressed() {}
func (_ VectorUint32) is_vector_uncompressed() {}
func (_ VectorUint64) is_vector_uncompressed() {}
func (_ VectorString) is_vector_uncompressed() {}

type VectorCompressed interface {
	is_vector_compressed()

	Decompressed() VectorUncompressed
}

func (_ VectorDict) is_vector_compressed() {}
func (_ VectorSize) is_vector_compressed() {}
func (_ VectorBias) is_vector_compressed() {}

type Vector interface {
	is_vector()
	zeroedVectorWithCount(count int) VectorUncompressed

	Count() int
}

func (_ VectorUint8) is_vector()  {}
func (_ VectorUint16) is_vector() {}
func (_ VectorUint32) is_vector() {}
func (_ VectorUint64) is_vector() {}
func (_ VectorString) is_vector() {}
func (_ VectorDict) is_vector()   {}
func (_ VectorSize) is_vector()   {}
func (_ VectorBias) is_vector()   {}

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

func Compressions() []Compression {
	return []Compression{
		Compression{tag: Dict},
		Compression{tag: Size},
		Compression{tag: Bias},
	}
}

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

func Compressed(vector VectorUncompressed, compression Compression) (VectorCompressed, bool) {
	switch compression.tag {
	case Dict:
		compressed, ok := vector.dictCompressed1()
		if ok {
			return VectorCompressed(compressed), true
		} else {
			return nil, false
		}
	case Size:
		switch vector.(type) {
		case VectorUncompressedInt:
			compressed, ok := vector.(VectorUncompressedInt).sizeCompressed1()
			if ok {
				return VectorCompressed(compressed), true
			} else {
				return nil, false
			}
		default:
			return nil, false
		}
	case Bias:
		compressed, ok := vector.biasCompressed1()
		if ok {
			return VectorCompressed(compressed), true
		} else {
			return nil, false
		}
	default:
		panic("Unreachable")
	}
}

func (vector VectorUint8) dictCompressed1() (VectorDict, bool) {
	return dictCompressed2([]uint8(vector))
}
func (vector VectorUint16) dictCompressed1() (VectorDict, bool) {
	return dictCompressed2([]uint16(vector))
}
func (vector VectorUint32) dictCompressed1() (VectorDict, bool) {
	return dictCompressed2([]uint32(vector))
}
func (vector VectorUint64) dictCompressed1() (VectorDict, bool) {
	return dictCompressed2([]uint64(vector))
}
func (vector VectorString) dictCompressed1() (VectorDict, bool) {
	return dictCompressed2([]string(vector))
}

func dictCompressed2[Value comparable](values []Value) (VectorDict, bool) {
	unique_values := make([]Value, 0)
	dict := make(map[Value]uint64)
	for _, value := range values {
		if _, ok := dict[value]; !ok {
			dict[value] = uint64(len(unique_values))
			unique_values = append(unique_values, value)
		}
	}
	codes := make([]uint64, len(values))
	for i, value := range values {
		codes[i] = dict[value]
	}
	result := VectorDict{
		codes:        VectorFromValues(codes).(Vector),
		uniqueValues: VectorFromValues(unique_values).(Vector),
	}
	return result, true
}

func (vector VectorUint8) sizeCompressed1() (VectorSize, bool) {
	return sizeCompressed2(8, []uint8(vector))
}
func (vector VectorUint16) sizeCompressed1() (VectorSize, bool) {
	return sizeCompressed2(16, []uint16(vector))
}
func (vector VectorUint32) sizeCompressed1() (VectorSize, bool) {
	return sizeCompressed2(32, []uint32(vector))
}
func (vector VectorUint64) sizeCompressed1() (VectorSize, bool) {
	return sizeCompressed2(64, []uint64(vector))
}

func sizeCompressed2[Value constraints.Integer](originalSizeBits uint8, values []Value) (VectorSize, bool) {
	if len(values) == 0 {
		return VectorSize{}, false
	}
	var max_value Value
	for _, value := range values {
		// TODO go 1.21 has a `max` function
		if value > max_value {
			max_value = value
		}
	}
	var values_compressed Vector
	if uint64(max_value) < (1<<8) && 8 < originalSizeBits {
		values_compressed = VectorFromValues(sizeCompressed3[Value, uint8](values)).(Vector)
	} else if uint64(max_value) < (1<<16) && 16 < originalSizeBits {
		values_compressed = VectorFromValues(sizeCompressed3[Value, uint16](values)).(Vector)
	} else if uint64(max_value) < (1<<32) && 32 < originalSizeBits {
		values_compressed = VectorFromValues(sizeCompressed3[Value, uint32](values)).(Vector)
	} else {
		return VectorSize{}, false
	}
	result := VectorSize{
		originalSizeBits: originalSizeBits,
		values:           values_compressed,
	}
	return result, true
}

func sizeCompressed3[From constraints.Integer, To constraints.Integer](from []From) []To {
	var to = make([]To, len(from))
	for i, value := range from {
		to[i] = To(value)
	}
	return to
}

func (vector VectorUint8) biasCompressed1() (VectorBias, bool) {
	return biasCompressed2([]uint8(vector))
}
func (vector VectorUint16) biasCompressed1() (VectorBias, bool) {
	return biasCompressed2([]uint16(vector))
}
func (vector VectorUint32) biasCompressed1() (VectorBias, bool) {
	return biasCompressed2([]uint32(vector))
}
func (vector VectorUint64) biasCompressed1() (VectorBias, bool) {
	return biasCompressed2([]uint64(vector))
}
func (vector VectorString) biasCompressed1() (VectorBias, bool) {
	return biasCompressed2([]string(vector))
}

func biasCompressed2[Value comparable](values []Value) (VectorBias, bool) {
	if len(values) == 0 {
		return VectorBias{}, false
	}

	var counts = make(map[Value]int)
	for _, value := range values {
		counts[value] += 1
	}
	var common_value Value = values[0]
	var common_count int = 0
	for value, count := range counts {
		if count > common_count {
			common_value = value
			common_count = count
		}
	}

	var presence = roaring.New()
	var remainder = make([]Value, 0, len(values)-common_count)
	for i, value := range values {
		if value == common_value {
			presence.Add(uint32(i))
		} else {
			remainder = append(remainder, value)
		}
	}

	result := VectorBias{
		count:     len(values),
		value:     BoxedValueFromValue(common_value),
		presence:  *presence,
		remainder: VectorFromValues(remainder).(Vector),
	}
	return result, true
}

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
