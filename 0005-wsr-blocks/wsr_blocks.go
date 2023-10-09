package wsr_blocks

import (
	"github.com/RoaringBitmap/roaring"
	"golang.org/x/exp/constraints"
)

func (vector Vector) Compressed(compression Compression) (Vector, bool) {
	if vector.compression != Raw {
		return Vector{}, false
	}
	switch compression {
	case Raw:
		return Vector{}, false
	case Dict:
		if elems, ok := vector.AsRawUint8(); ok {
			return dictCompress(elems)
		} else if elems, ok := vector.AsRawUint16(); ok {
			return dictCompress(elems)
		} else if elems, ok := vector.AsRawUint32(); ok {
			return dictCompress(elems)
		} else if elems, ok := vector.AsRawUint64(); ok {
			return dictCompress(elems)
		} else if elems, ok := vector.AsRawString(); ok {
			return dictCompress(elems)
		} else {
			return Vector{}, false
		}
	case RunLength:
		if elems, ok := vector.AsRawUint8(); ok {
			return runLengthCompress(elems)
		} else if elems, ok := vector.AsRawUint16(); ok {
			return runLengthCompress(elems)
		} else if elems, ok := vector.AsRawUint32(); ok {
			return runLengthCompress(elems)
		} else if elems, ok := vector.AsRawUint64(); ok {
			return runLengthCompress(elems)
		} else if _, ok := vector.AsRawString(); ok {
			return Vector{}, false
		} else {
			return Vector{}, false
		}
	case Bias:
		if elems, ok := vector.AsRawUint8(); ok {
			return biasCompress(elems)
		} else if elems, ok := vector.AsRawUint16(); ok {
			return biasCompress(elems)
		} else if elems, ok := vector.AsRawUint32(); ok {
			return biasCompress(elems)
		} else if elems, ok := vector.AsRawUint64(); ok {
			return biasCompress(elems)
		} else if elems, ok := vector.AsRawString(); ok {
			return biasCompress(elems)
		} else {
			return Vector{}, false
		}
	default:
		panic("!")
	}
}

func dictCompress[Elem comparable](elems []Elem) (Vector, bool) {
	unique_elems := make([]Elem, 0)
	dict := make(map[Elem]uint64)
	for _, elem := range elems {
		if _, ok := dict[elem]; !ok {
			dict[elem] = uint64(len(unique_elems))
			unique_elems = append(unique_elems, elem)
		}
	}
	codes := make([]uint64, len(elems))
	for i, elem := range elems {
		codes[i] = dict[elem]
	}
	result := Vector{
		Kind:        kindFromElems(elems),
		compression: Dict,
		data: dictCompressedElems{
			codes:       VectorFromElems(codes),
			uniqueElems: VectorFromElems(unique_elems),
		},
	}
	return result, true
}

func runLengthCompress[Elem constraints.Integer](elems []Elem) (Vector, bool) {
	var max_elem Elem
	for _, elem := range elems {
		// TODO go 1.21 has a `max` function
		if elem > max_elem {
			max_elem = elem
		}
	}
	var result_inner Vector
	switch {
	case uint64(max_elem) < (1 << 8):
		result_inner = VectorFromElems(runLengthCompressTo[Elem, uint8](elems))
	case uint64(max_elem) < (1 << 16):
		result_inner = VectorFromElems(runLengthCompressTo[Elem, uint16](elems))
	case uint64(max_elem) < (1 << 32):
		result_inner = VectorFromElems(runLengthCompressTo[Elem, uint32](elems))
	default:
		return Vector{}, false
	}
	result := Vector{
		Kind:        kindFromElems(elems),
		compression: RunLength,
		data: runLengthCompressedElems{
			elems: result_inner,
		},
	}
	return result, true
}

func runLengthCompressTo[From constraints.Integer, To constraints.Integer](from []From) []To {
	var to = make([]To, len(from))
	for i, elem := range from {
		to[i] = To(elem)
	}
	return to
}

func biasCompress[Elem comparable](elems []Elem) (Vector, bool) {
	if len(elems) == 0 {
		return Vector{}, false
	}

	var counts = make(map[Elem]int)
	for _, elem := range elems {
		counts[elem] += 1
	}
	var max_elem Elem = elems[0]
	var max_count int = 0
	for elem, count := range counts {
		if count > max_count {
			max_elem = elem
			max_count = count
		}
	}

	var presence = roaring.New()
	var remainder = make([]Elem, 0, len(elems)-max_count)
	for i, elem := range elems {
		if elem == max_elem {
			presence.Add(uint32(i))
		} else {
			remainder = append(remainder, elem)
		}
	}

	result := Vector{
		Kind:        kindFromElems(elems),
		compression: Bias,
		data: biasCompressedElems{
			count: len(elems),
			elem: BoxedElem{
				Kind: kindFromElem(max_elem),
				Data: max_elem,
			},
			presence:  *presence,
			remainder: VectorFromElems(remainder),
		},
	}
	return result, true
}

// TODO Would be much cheaper to specialize `Get` for the whole stack of Compressions rather than decompressing intermediate slices. But probably not possible in go.
func (vector Vector) Decompressed() Vector {
	if vector.compression == Raw {
		return vector
	}

	result := vector.zeroedVector()
	if data, ok := vector.asDictCompressed(); ok {
		dictDecompress1(data.uniqueElems.Decompressed().data, data.codes.Decompressed().data, result.data)
	} else if data, ok := vector.asRunLengthCompressed(); ok {
		runLengthDecompress1(data.elems.Decompressed().data, result.data)
	} else if data, ok := vector.asBiasCompressed(); ok {
		biasDecompress1(data.elem.Data, data.presence, data.remainder.Decompressed().data, result.data)
	} else {
		panic("Unreachable")
	}
	return result
}

func dictDecompress1(uniqueElems interface{}, codes interface{}, to interface{}) {
	switch uniqueElems.(type) {
	case []uint8:
		dictDecompress2(uniqueElems.([]uint8), codes, to.([]uint8))
	case []uint16:
		dictDecompress2(uniqueElems.([]uint16), codes, to.([]uint16))
	case []uint32:
		dictDecompress2(uniqueElems.([]uint32), codes, to.([]uint32))
	case []uint64:
		dictDecompress2(uniqueElems.([]uint64), codes, to.([]uint64))
	case []string:
		dictDecompress2(uniqueElems.([]string), codes, to.([]string))
	}
}

func dictDecompress2[Elem any](uniqueElems []Elem, codes interface{}, to []Elem) {
	switch codes.(type) {
	case []uint8:
		dictDecompress3(uniqueElems, codes.([]uint8), to)
	case []uint16:
		dictDecompress3(uniqueElems, codes.([]uint16), to)
	case []uint32:
		dictDecompress3(uniqueElems, codes.([]uint32), to)
	case []uint64:
		dictDecompress3(uniqueElems, codes.([]uint64), to)
	}
}

func dictDecompress3[Elem any, Code constraints.Integer](uniqueElems []Elem, codes []Code, to []Elem) {
	for i := range to {
		to[i] = uniqueElems[codes[i]]
	}
}

func runLengthDecompress1(from interface{}, to interface{}) {
	switch from.(type) {
	case []uint8:
		runLengthDecompress2(from.([]uint8), to)
	case []uint16:
		runLengthDecompress2(from.([]uint16), to)
	case []uint32:
		runLengthDecompress2(from.([]uint32), to)
	case []uint64:
		runLengthDecompress2(from.([]uint64), to)
	}
}

func runLengthDecompress2[From constraints.Integer](from []From, to interface{}) {
	switch to.(type) {
	case []uint8:
		runLengthDecompress3(from, to.([]uint8))
	case []uint16:
		runLengthDecompress3(from, to.([]uint16))
	case []uint32:
		runLengthDecompress3(from, to.([]uint32))
	case []uint64:
		runLengthDecompress3(from, to.([]uint64))
	}
}

func runLengthDecompress3[From constraints.Integer, To constraints.Integer](from []From, to []To) {
	for i := range from {
		to[i] = To(from[i])
	}
}

func biasDecompress1(elem interface{}, presence roaring.Bitmap, remainder interface{}, to interface{}) {
	switch remainder.(type) {
	case []uint8:
		biasDecompress2(elem.(uint8), presence, remainder.([]uint8), to.([]uint8))
	case []uint16:
		biasDecompress2(elem.(uint16), presence, remainder.([]uint16), to.([]uint16))
	case []uint32:
		biasDecompress2(elem.(uint32), presence, remainder.([]uint32), to.([]uint32))
	case []uint64:
		biasDecompress2(elem.(uint64), presence, remainder.([]uint64), to.([]uint64))
	case []string:
		biasDecompress2(elem.(string), presence, remainder.([]string), to.([]string))
	}
}

func biasDecompress2[Elem comparable](elem Elem, presence roaring.Bitmap, remainder []Elem, to []Elem) {
	var remainder_index int = 0
	for i := range to {
		if presence.ContainsInt(i) {
			to[i] = elem
		} else {
			to[i] = remainder[remainder_index]
			remainder_index++
		}
	}
}
