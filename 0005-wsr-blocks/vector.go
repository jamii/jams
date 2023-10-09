package wsr_blocks

import (
	"github.com/RoaringBitmap/roaring"
)

type Kind = uint64

const (
	Uint8 Kind = iota
	Uint16
	Uint32
	Uint64
	String
)

type BoxedElem struct {
	Kind Kind
	// Just heap-allocate all elems for now.
	Data interface{}
}

type Compression = uint64

const (
	Raw Compression = iota
	Dict
	RunLength
	Bias
)

func Compressions() []Compression {
	return []Compression{
		Dict,
		RunLength,
		Bias,
	}
}

type Vector struct {
	Kind        Kind
	compression Compression
	data        interface{}
}

type dictCompressedElems struct {
	codes       Vector
	uniqueElems Vector
}

type runLengthCompressedElems struct {
	elems Vector
}

type biasCompressedElems struct {
	count     int
	elem      BoxedElem
	presence  roaring.Bitmap
	remainder Vector
}

func kindFromElem(elem interface{}) Kind {
	switch elem.(type) {
	case uint8:
		return Uint8
	case uint16:
		return Uint16
	case uint32:
		return Uint32
	case uint64:
		return Uint64
	case string:
		return String
	default:
		panic("Unsupported elem kind")
	}
}

func kindFromElems(elems interface{}) Kind {
	switch elems.(type) {
	case []uint8:
		return Uint8
	case []uint16:
		return Uint16
	case []uint32:
		return Uint32
	case []uint64:
		return Uint64
	case []string:
		return String
	default:
		panic("Unsupported elem kind")
	}
}

func (vector Vector) zeroedElems() interface{} {
	switch vector.Kind {
	case Uint8:
		return make([]uint8, vector.Count())
	case Uint16:
		return make([]uint16, vector.Count())
	case Uint32:
		return make([]uint32, vector.Count())
	case Uint64:
		return make([]uint64, vector.Count())
	case String:
		return make([]string, vector.Count())
	default:
		panic("Unreachable")
	}
}

func (vector Vector) zeroedVector() Vector {
	switch vector.Kind {
	case Uint8:
		return VectorFromElems(make([]uint8, vector.Count()))
	case Uint16:
		return VectorFromElems(make([]uint16, vector.Count()))
	case Uint32:
		return VectorFromElems(make([]uint32, vector.Count()))
	case Uint64:
		return VectorFromElems(make([]uint64, vector.Count()))
	case String:
		return VectorFromElems(make([]string, vector.Count()))
	default:
		panic("Unreachable")
	}
}

func VectorFromElems[Elem any](elems []Elem) Vector {
	return Vector{
		Kind:        kindFromElems(elems),
		compression: Raw,
		data:        elems,
	}
}

func (vector Vector) AsRaw() (interface{}, bool) {
	if vector.compression == Raw {
		return vector.data, true
	} else {
		return nil, false
	}
}

func (vector Vector) AsRawUint8() ([]uint8, bool) {
	if vector.compression == Raw && vector.Kind == Uint8 {
		return vector.data.([]uint8), true
	} else {
		return nil, false
	}
}

func (vector Vector) AsRawUint16() ([]uint16, bool) {
	if vector.compression == Raw && vector.Kind == Uint16 {
		return vector.data.([]uint16), true
	} else {
		return nil, false
	}
}

func (vector Vector) AsRawUint32() ([]uint32, bool) {
	if vector.compression == Raw && vector.Kind == Uint32 {
		return vector.data.([]uint32), true
	} else {
		return nil, false
	}
}

func (vector Vector) AsRawUint64() ([]uint64, bool) {
	if vector.compression == Raw && vector.Kind == Uint64 {
		return vector.data.([]uint64), true
	} else {
		return nil, false
	}
}

func (vector Vector) AsRawString() ([]string, bool) {
	if vector.compression == Raw && vector.Kind == Uint16 {
		return vector.data.([]string), true
	} else {
		return nil, false
	}
}

func (vector Vector) asDictCompressed() (dictCompressedElems, bool) {
	if vector.compression == Dict {
		return vector.data.(dictCompressedElems), true
	} else {
		return dictCompressedElems{}, false
	}
}

func (vector Vector) asRunLengthCompressed() (runLengthCompressedElems, bool) {
	if vector.compression == RunLength {
		return vector.data.(runLengthCompressedElems), true
	} else {
		return runLengthCompressedElems{}, false
	}
}

func (vector Vector) asBiasCompressed() (biasCompressedElems, bool) {
	if vector.compression == Bias {
		return vector.data.(biasCompressedElems), true
	} else {
		return biasCompressedElems{}, false
	}
}

func (vector Vector) Count() int {
	if data, ok := vector.AsRawUint8(); ok {
		return len(data)
	} else if data, ok := vector.AsRawUint16(); ok {
		return len(data)
	} else if data, ok := vector.AsRawUint32(); ok {
		return len(data)
	} else if data, ok := vector.AsRawUint64(); ok {
		return len(data)
	} else if data, ok := vector.asDictCompressed(); ok {
		return data.codes.Count()
	} else if data, ok := vector.asRunLengthCompressed(); ok {
		return data.elems.Count()
	} else if data, ok := vector.asBiasCompressed(); ok {
		return data.count
	} else {
		panic("Unreachable")
	}
}
