package wsr_blocks

import (
	"golang.org/x/exp/constraints"
)

type Vector interface{}

type DictCompressedVector struct {
	Codes       Vector
	UniqueElems Vector
}

type Compression = int64

const (
	Raw Compression = iota
	Dict
	RunLength
)

func Compress(compression Compression, vector Vector) Vector {
	switch compression {
	case Raw:
		return vector
	case Dict:
		switch vector.(type) {
		case []uint64:
			return DictCompress(vector.([]uint64))
		case []string:
			return DictCompress(vector.([]string))
		default:
			panic("!")
		}
	case RunLength:
		switch vector.(type) {
		case []uint64:
			return RunLengthCompress(vector.([]uint64))
		case []string:
			panic("Unsupported")
		default:
			panic("!")
		}
	default:
		panic("!")
	}
}

func DictCompress[Elem comparable](vector []Elem) DictCompressedVector {
	unique_elems := make([]Elem, 0)
	dict := make(map[Elem]uint64)
	for _, elem := range vector {
		if _, ok := dict[elem]; !ok {
			dict[elem] = uint64(len(unique_elems))
			unique_elems = append(unique_elems, elem)
		}
	}
	codes := make([]uint64, len(vector))
	for i, elem := range vector {
		codes[i] = dict[elem]
	}
	return DictCompressedVector{
		Codes:       codes,
		UniqueElems: unique_elems,
	}
}

func RunLengthCompress[Elem constraints.Integer](vector []Elem) Vector {
	var max_elem Elem
	for _, elem := range vector {
		// TODO go 1.21 has a `max` function
		if elem > max_elem {
			max_elem = elem
		}
	}
	switch {
	case uint64(max_elem) < (1 << 8):
		return RunLengthCompressTo[Elem, uint8](vector)
	case uint64(max_elem) < (1 << 16):
		return RunLengthCompressTo[Elem, uint16](vector)
	case uint64(max_elem) < (1 << 32):
		return RunLengthCompressTo[Elem, uint32](vector)
	default:
		return vector
	}
}

func RunLengthCompressTo[From constraints.Integer, To constraints.Integer](from []From) []To {
	var to = make([]To, len(from))
	for i, elem := range from {
		to[i] = To(elem)
	}
	return to
}
