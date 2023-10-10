package wsr_blocks

type BoxedValue interface {
	is_boxed_value()
}

type BoxedValueUint8 uint8
type BoxedValueUint16 uint16
type BoxedValueUint32 uint32
type BoxedValueUint64 uint64
type BoxedValueString string

func (_ BoxedValueUint8) is_boxed_value()  {}
func (_ BoxedValueUint16) is_boxed_value() {}
func (_ BoxedValueUint32) is_boxed_value() {}
func (_ BoxedValueUint64) is_boxed_value() {}
func (_ BoxedValueString) is_boxed_value() {}

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
