package wsr_blocks

import (
	"github.com/RoaringBitmap/roaring"
	"golang.org/x/exp/constraints"
)

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

func Compressed(vector VectorUncompressed, compression Compression) (VectorCompressed, bool) {
	switch compression.tag {
	case Dict:
		compressed, ok := vector.DictCompressed()
		if ok {
			return VectorCompressed(compressed), true
		} else {
			return nil, false
		}
	case Size:
		switch vector.(type) {
		case VectorUncompressedInt:
			compressed, ok := vector.(VectorUncompressedInt).SizeCompressed()
			if ok {
				return VectorCompressed(compressed), true
			} else {
				return nil, false
			}
		default:
			return nil, false
		}
	case Bias:
		compressed, ok := vector.BiasCompressed()
		if ok {
			return VectorCompressed(compressed), true
		} else {
			return nil, false
		}
	default:
		panic("Unreachable")
	}
}

func (vector VectorUint8) DictCompressed() (VectorDict, bool) {
	return dictCompressed1([]uint8(vector))
}
func (vector VectorUint16) DictCompressed() (VectorDict, bool) {
	return dictCompressed1([]uint16(vector))
}
func (vector VectorUint32) DictCompressed() (VectorDict, bool) {
	return dictCompressed1([]uint32(vector))
}
func (vector VectorUint64) DictCompressed() (VectorDict, bool) {
	return dictCompressed1([]uint64(vector))
}
func (vector VectorString) DictCompressed() (VectorDict, bool) {
	return dictCompressed1([]string(vector))
}

func dictCompressed1[Value comparable](values []Value) (VectorDict, bool) {
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

func (vector VectorUint8) SizeCompressed() (VectorSize, bool) {
	return sizeCompressed1(8, []uint8(vector))
}
func (vector VectorUint16) SizeCompressed() (VectorSize, bool) {
	return sizeCompressed1(16, []uint16(vector))
}
func (vector VectorUint32) SizeCompressed() (VectorSize, bool) {
	return sizeCompressed1(32, []uint32(vector))
}
func (vector VectorUint64) SizeCompressed() (VectorSize, bool) {
	return sizeCompressed1(64, []uint64(vector))
}

func sizeCompressed1[Value constraints.Integer](originalSizeBits uint8, values []Value) (VectorSize, bool) {
	var max_value Value
	for _, value := range values {
		// TODO go 1.21 has a `max` function
		if value > max_value {
			max_value = value
		}
	}
	var values_compressed Vector
	if uint64(max_value) < (1<<8) && 8 < originalSizeBits {
		values_compressed = VectorFromValues(sizeCompressed2[Value, uint8](values)).(Vector)
	} else if uint64(max_value) < (1<<16) && 16 < originalSizeBits {
		values_compressed = VectorFromValues(sizeCompressed2[Value, uint16](values)).(Vector)
	} else if uint64(max_value) < (1<<32) && 32 < originalSizeBits {
		values_compressed = VectorFromValues(sizeCompressed2[Value, uint32](values)).(Vector)
	} else {
		return VectorSize{}, false
	}
	result := VectorSize{
		originalSizeBits: originalSizeBits,
		values:           values_compressed,
	}
	return result, true
}

func sizeCompressed2[From constraints.Integer, To constraints.Integer](from []From) []To {
	var to = make([]To, len(from))
	for i, value := range from {
		to[i] = To(value)
	}
	return to
}

func (vector VectorUint8) BiasCompressed() (VectorBias, bool) {
	return biasCompressed1([]uint8(vector))
}
func (vector VectorUint16) BiasCompressed() (VectorBias, bool) {
	return biasCompressed1([]uint16(vector))
}
func (vector VectorUint32) BiasCompressed() (VectorBias, bool) {
	return biasCompressed1([]uint32(vector))
}
func (vector VectorUint64) BiasCompressed() (VectorBias, bool) {
	return biasCompressed1([]uint64(vector))
}
func (vector VectorString) BiasCompressed() (VectorBias, bool) {
	return biasCompressed1([]string(vector))
}

func biasCompressed1[Value comparable](values []Value) (VectorBias, bool) {
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

func (vector VectorSize) Decompressed() VectorUncompressed {
	result := zeroedVector(vector)
	sizeDecompress1(ensureDecompressed(vector.values), result)
	return result
}

func (vector VectorBias) Decompressed() VectorUncompressed {
	result := zeroedVector(vector)
	biasDecompress1(vector.value, vector.presence, ensureDecompressed(vector.remainder), result)
	return result
}

func dictDecompress1(uniqueValues VectorUncompressed, codes VectorUncompressed, to VectorUncompressed) {
	switch uniqueValues.(type) {
	case VectorUint8:
		dictDecompress2([]uint8(uniqueValues.(VectorUint8)), codes, []uint8(to.(VectorUint8)))
	case VectorUint16:
		dictDecompress2([]uint16(uniqueValues.(VectorUint16)), codes, []uint16(to.(VectorUint16)))
	case VectorUint32:
		dictDecompress2([]uint32(uniqueValues.(VectorUint32)), codes, []uint32(to.(VectorUint32)))
	case VectorUint64:
		dictDecompress2([]uint64(uniqueValues.(VectorUint64)), codes, []uint64(to.(VectorUint64)))
	case VectorString:
		dictDecompress2([]string(uniqueValues.(VectorString)), codes, []string(to.(VectorString)))
	}
}

func dictDecompress2[Value any](uniqueValues []Value, codes interface{}, to []Value) {
	switch codes.(type) {
	case VectorUint8:
		dictDecompress3(uniqueValues, []uint8(codes.(VectorUint8)), to)
	case VectorUint16:
		dictDecompress3(uniqueValues, []uint16(codes.(VectorUint16)), to)
	case VectorUint32:
		dictDecompress3(uniqueValues, []uint32(codes.(VectorUint32)), to)
	case VectorUint64:
		dictDecompress3(uniqueValues, []uint64(codes.(VectorUint64)), to)
	}
}

func dictDecompress3[Value any, Code constraints.Integer](uniqueValues []Value, codes []Code, to []Value) {
	for i := range to {
		to[i] = uniqueValues[codes[i]]
	}
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
