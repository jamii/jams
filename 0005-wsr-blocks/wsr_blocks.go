package wsr_blocks

import (
	"golang.org/x/exp/constraints"
)

func (vector Vector) Compress(compression Compression) (Vector, bool) {
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
			panic("!")
		}
	case RunLength:
		if elems, ok := vector.AsRawUint8(); ok {
			return RunLengthCompress(elems)
		} else if elems, ok := vector.AsRawUint16(); ok {
			return RunLengthCompress(elems)
		} else if elems, ok := vector.AsRawUint32(); ok {
			return RunLengthCompress(elems)
		} else if elems, ok := vector.AsRawUint64(); ok {
			return RunLengthCompress(elems)
		} else if _, ok := vector.AsRawString(); ok {
			return Vector{}, false
		} else {
			panic("!")
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
		Kind:        KindFromElems(elems),
		compression: Dict,
		data: dictCompressedElems{
			codes:       VectorFromElems(codes),
			uniqueElems: VectorFromElems(unique_elems),
		},
	}
	return result, true
}

func RunLengthCompress[Elem constraints.Integer](elems []Elem) (Vector, bool) {
	var max_elem Elem
	for _, elem := range elems {
		// TODO go 1.21 has a `max` function
		if elem > max_elem {
			max_elem = elem
		}
	}
	switch {
	case uint64(max_elem) < (1 << 8):
		return VectorFromElems(runLengthCompressTo[Elem, uint8](elems)), true
	case uint64(max_elem) < (1 << 16):
		return VectorFromElems(runLengthCompressTo[Elem, uint16](elems)), true
	case uint64(max_elem) < (1 << 32):
		return VectorFromElems(runLengthCompressTo[Elem, uint32](elems)), true
	default:
		return Vector{}, false
	}
}

func runLengthCompressTo[From constraints.Integer, To constraints.Integer](from []From) []To {
	var to = make([]To, len(from))
	for i, elem := range from {
		to[i] = To(elem)
	}
	return to
}

func (vector Vector) Decompress() (Vector, bool) {
	if vector.compression == Raw {
		return Vector{}, false
	}
	panic("TODO")
}
