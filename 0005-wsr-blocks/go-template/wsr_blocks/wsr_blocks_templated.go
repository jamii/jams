package wsr_blocks

import (
    "github.com/RoaringBitmap/roaring"
)




type BoxedValueUint8 uint8
func (_ BoxedValueUint8) is_boxed_value() {}
type VectorUint8 []uint8
func (_ VectorUint8) is_vector_uncompressed_int()  {}
func (_ VectorUint8) is_vector_uncompressed()  {}
func (_ VectorUint8) is_vector()  {}

type BoxedValueUint16 uint16
func (_ BoxedValueUint16) is_boxed_value() {}
type VectorUint16 []uint16
func (_ VectorUint16) is_vector_uncompressed_int()  {}
func (_ VectorUint16) is_vector_uncompressed()  {}
func (_ VectorUint16) is_vector()  {}

type BoxedValueUint32 uint32
func (_ BoxedValueUint32) is_boxed_value() {}
type VectorUint32 []uint32
func (_ VectorUint32) is_vector_uncompressed_int()  {}
func (_ VectorUint32) is_vector_uncompressed()  {}
func (_ VectorUint32) is_vector()  {}

type BoxedValueUint64 uint64
func (_ BoxedValueUint64) is_boxed_value() {}
type VectorUint64 []uint64
func (_ VectorUint64) is_vector_uncompressed_int()  {}
func (_ VectorUint64) is_vector_uncompressed()  {}
func (_ VectorUint64) is_vector()  {}

type BoxedValueString string
func (_ BoxedValueString) is_boxed_value() {}
type VectorString []string

func (_ VectorString) is_vector_uncompressed()  {}
func (_ VectorString) is_vector()  {}



func (_ VectorDict) is_vector_compressed() {}
func (_ VectorDict) is_vector()  {}

func (_ VectorSize) is_vector_compressed() {}
func (_ VectorSize) is_vector()  {}

func (_ VectorBias) is_vector_compressed() {}
func (_ VectorBias) is_vector()  {}


func Compressions() []Compression {
    return []Compression{
        
        Compression{tag: Dict},
        Compression{tag: Dict},
        Compression{tag: Dict},
        
        Compression{tag: Size},
        Compression{tag: Size},
        Compression{tag: Size},
        
        Compression{tag: Bias},
        Compression{tag: Bias},
        Compression{tag: Bias},
        
    }
}

func Compressed(vector VectorUncompressed, compression Compression) (VectorCompressed, bool) {
    switch vector.(type) {
        
        case VectorUint8:
        {
            values := []uint8(vector.(VectorUint8))
            switch compression.tag {
                case Dict:
                {
                    codes := make([]uint64, len(values))
                    unique_values := make([]uint8, 0)
                    
                    dict := make(map[uint8]uint64)
                    
                    for i, value := range values {
                        var code uint64
                        code, ok := dict[value]
                        if !ok {
                            code = uint64(len(unique_values))
                            dict[value] = code
                            unique_values = append(unique_values, value)
                        }
                        codes[i] = code
                    }
                    
                    result := VectorDict{
                        codes:        VectorUint64(codes),
                        uniqueValues: VectorUint8(unique_values),
                    }
                    return VectorCompressed(result), true
                }
                case Size:
                {
                    
                    {
                        const originalSizeBits uint8 = 8
                        
                        if len(values) == 0 {
                            return nil, false
                        }
                        
                        var max_value uint8
                        for _, value := range values {
                            // TODO go 1.21 has a `max` function
                            if value > max_value {
                                max_value = value
                            }
                        }
                        
                        
                        {
                            
                            
                            
                        }
                        
                        {
                            
                            
                            
                        }
                        
                        {
                            
                            
                            
                        }
                        
                        {
                            
                            
                            
                        }
                        
                        {
                            
                        }
                        
                        return nil, false
                    }
                    
                }
                case Bias:
                {
                    if len(values) == 0 {
                        return nil, false
                    }
                    
                    var counts = make(map[uint8]int)
                    for _, value := range values {
                        counts[value] += 1
                    }
                    var common_value uint8 = values[0]
                    var common_count int = 0
                    for value, count := range counts {
                        if count > common_count {
                            common_value = value
                            common_count = count
                        }
                    }
                    
                    var presence = roaring.New()
                    var remainder = make([]uint8, 0, len(values)-common_count)
                    for i, value := range values {
                        if value == common_value {
                            presence.Add(uint32(i))
                        } else {
                            remainder = append(remainder, value)
                        }
                    }
                    
                    result := VectorBias{
                        count:     len(values),
                        value:     BoxedValueUint8(common_value),
                        presence:  *presence,
                        remainder: VectorUint8(remainder),
                    }
                    return result, true
                }
                default:
                panic("Unreachable")
            }
        }
        
        case VectorUint16:
        {
            values := []uint16(vector.(VectorUint16))
            switch compression.tag {
                case Dict:
                {
                    codes := make([]uint64, len(values))
                    unique_values := make([]uint16, 0)
                    
                    dict := make(map[uint16]uint64)
                    
                    for i, value := range values {
                        var code uint64
                        code, ok := dict[value]
                        if !ok {
                            code = uint64(len(unique_values))
                            dict[value] = code
                            unique_values = append(unique_values, value)
                        }
                        codes[i] = code
                    }
                    
                    result := VectorDict{
                        codes:        VectorUint64(codes),
                        uniqueValues: VectorUint16(unique_values),
                    }
                    return VectorCompressed(result), true
                }
                case Size:
                {
                    
                    {
                        const originalSizeBits uint8 = 16
                        
                        if len(values) == 0 {
                            return nil, false
                        }
                        
                        var max_value uint16
                        for _, value := range values {
                            // TODO go 1.21 has a `max` function
                            if value > max_value {
                                max_value = value
                            }
                        }
                        
                        
                        {
                            
                            
                            
                        }
                        
                        {
                            
                            
                            
                        }
                        
                        {
                            
                            
                            
                        }
                        
                        {
                            
                            
                            
                        }
                        
                        {
                            
                        }
                        
                        return nil, false
                    }
                    
                }
                case Bias:
                {
                    if len(values) == 0 {
                        return nil, false
                    }
                    
                    var counts = make(map[uint16]int)
                    for _, value := range values {
                        counts[value] += 1
                    }
                    var common_value uint16 = values[0]
                    var common_count int = 0
                    for value, count := range counts {
                        if count > common_count {
                            common_value = value
                            common_count = count
                        }
                    }
                    
                    var presence = roaring.New()
                    var remainder = make([]uint16, 0, len(values)-common_count)
                    for i, value := range values {
                        if value == common_value {
                            presence.Add(uint32(i))
                        } else {
                            remainder = append(remainder, value)
                        }
                    }
                    
                    result := VectorBias{
                        count:     len(values),
                        value:     BoxedValueUint16(common_value),
                        presence:  *presence,
                        remainder: VectorUint16(remainder),
                    }
                    return result, true
                }
                default:
                panic("Unreachable")
            }
        }
        
        case VectorUint32:
        {
            values := []uint32(vector.(VectorUint32))
            switch compression.tag {
                case Dict:
                {
                    codes := make([]uint64, len(values))
                    unique_values := make([]uint32, 0)
                    
                    dict := make(map[uint32]uint64)
                    
                    for i, value := range values {
                        var code uint64
                        code, ok := dict[value]
                        if !ok {
                            code = uint64(len(unique_values))
                            dict[value] = code
                            unique_values = append(unique_values, value)
                        }
                        codes[i] = code
                    }
                    
                    result := VectorDict{
                        codes:        VectorUint64(codes),
                        uniqueValues: VectorUint32(unique_values),
                    }
                    return VectorCompressed(result), true
                }
                case Size:
                {
                    
                    {
                        const originalSizeBits uint8 = 32
                        
                        if len(values) == 0 {
                            return nil, false
                        }
                        
                        var max_value uint32
                        for _, value := range values {
                            // TODO go 1.21 has a `max` function
                            if value > max_value {
                                max_value = value
                            }
                        }
                        
                        
                        {
                            
                            
                            
                        }
                        
                        {
                            
                            
                            
                        }
                        
                        {
                            
                            
                            
                        }
                        
                        {
                            
                            
                            
                        }
                        
                        {
                            
                        }
                        
                        return nil, false
                    }
                    
                }
                case Bias:
                {
                    if len(values) == 0 {
                        return nil, false
                    }
                    
                    var counts = make(map[uint32]int)
                    for _, value := range values {
                        counts[value] += 1
                    }
                    var common_value uint32 = values[0]
                    var common_count int = 0
                    for value, count := range counts {
                        if count > common_count {
                            common_value = value
                            common_count = count
                        }
                    }
                    
                    var presence = roaring.New()
                    var remainder = make([]uint32, 0, len(values)-common_count)
                    for i, value := range values {
                        if value == common_value {
                            presence.Add(uint32(i))
                        } else {
                            remainder = append(remainder, value)
                        }
                    }
                    
                    result := VectorBias{
                        count:     len(values),
                        value:     BoxedValueUint32(common_value),
                        presence:  *presence,
                        remainder: VectorUint32(remainder),
                    }
                    return result, true
                }
                default:
                panic("Unreachable")
            }
        }
        
        case VectorUint64:
        {
            values := []uint64(vector.(VectorUint64))
            switch compression.tag {
                case Dict:
                {
                    codes := make([]uint64, len(values))
                    unique_values := make([]uint64, 0)
                    
                    dict := make(map[uint64]uint64)
                    
                    for i, value := range values {
                        var code uint64
                        code, ok := dict[value]
                        if !ok {
                            code = uint64(len(unique_values))
                            dict[value] = code
                            unique_values = append(unique_values, value)
                        }
                        codes[i] = code
                    }
                    
                    result := VectorDict{
                        codes:        VectorUint64(codes),
                        uniqueValues: VectorUint64(unique_values),
                    }
                    return VectorCompressed(result), true
                }
                case Size:
                {
                    
                    {
                        const originalSizeBits uint8 = 64
                        
                        if len(values) == 0 {
                            return nil, false
                        }
                        
                        var max_value uint64
                        for _, value := range values {
                            // TODO go 1.21 has a `max` function
                            if value > max_value {
                                max_value = value
                            }
                        }
                        
                        
                        {
                            
                            
                            
                        }
                        
                        {
                            
                            
                            
                        }
                        
                        {
                            
                            
                            
                        }
                        
                        {
                            
                            
                            
                        }
                        
                        {
                            
                        }
                        
                        return nil, false
                    }
                    
                }
                case Bias:
                {
                    if len(values) == 0 {
                        return nil, false
                    }
                    
                    var counts = make(map[uint64]int)
                    for _, value := range values {
                        counts[value] += 1
                    }
                    var common_value uint64 = values[0]
                    var common_count int = 0
                    for value, count := range counts {
                        if count > common_count {
                            common_value = value
                            common_count = count
                        }
                    }
                    
                    var presence = roaring.New()
                    var remainder = make([]uint64, 0, len(values)-common_count)
                    for i, value := range values {
                        if value == common_value {
                            presence.Add(uint32(i))
                        } else {
                            remainder = append(remainder, value)
                        }
                    }
                    
                    result := VectorBias{
                        count:     len(values),
                        value:     BoxedValueUint64(common_value),
                        presence:  *presence,
                        remainder: VectorUint64(remainder),
                    }
                    return result, true
                }
                default:
                panic("Unreachable")
            }
        }
        
        case VectorString:
        {
            values := []string(vector.(VectorString))
            switch compression.tag {
                case Dict:
                {
                    codes := make([]uint64, len(values))
                    unique_values := make([]string, 0)
                    
                    dict := make(map[string]uint64)
                    
                    for i, value := range values {
                        var code uint64
                        code, ok := dict[value]
                        if !ok {
                            code = uint64(len(unique_values))
                            dict[value] = code
                            unique_values = append(unique_values, value)
                        }
                        codes[i] = code
                    }
                    
                    result := VectorDict{
                        codes:        VectorUint64(codes),
                        uniqueValues: VectorString(unique_values),
                    }
                    return VectorCompressed(result), true
                }
                case Size:
                {
                    
                    {
                        return nil, false
                    }
                    
                }
                case Bias:
                {
                    if len(values) == 0 {
                        return nil, false
                    }
                    
                    var counts = make(map[string]int)
                    for _, value := range values {
                        counts[value] += 1
                    }
                    var common_value string = values[0]
                    var common_count int = 0
                    for value, count := range counts {
                        if count > common_count {
                            common_value = value
                            common_count = count
                        }
                    }
                    
                    var presence = roaring.New()
                    var remainder = make([]string, 0, len(values)-common_count)
                    for i, value := range values {
                        if value == common_value {
                            presence.Add(uint32(i))
                        } else {
                            remainder = append(remainder, value)
                        }
                    }
                    
                    result := VectorBias{
                        count:     len(values),
                        value:     BoxedValueString(common_value),
                        presence:  *presence,
                        remainder: VectorString(remainder),
                    }
                    return result, true
                }
                default:
                panic("Unreachable")
            }
        }
        
        default:
        panic("Unreachable")
    }
}