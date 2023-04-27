#include <math.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

static uint16_t i16_byteswap(uint16_t src) {
    return (uint16_t)(uint8_t)(src >> 0) << 8 |
           (uint16_t)(uint8_t)(src >> 8) << 0;
}
static uint32_t i32_byteswap(uint32_t src) {
    return (uint32_t)i16_byteswap(src >>  0) << 16 |
           (uint32_t)i16_byteswap(src >> 16) <<  0;
}
static uint64_t i64_byteswap(uint64_t src) {
    return (uint64_t)i32_byteswap(src >>  0) << 32 |
           (uint64_t)i32_byteswap(src >> 32) <<  0;
}

static uint16_t load16_align0(const uint8_t *ptr) {
    uint16_t val;
    memcpy(&val, ptr, sizeof(val));
    return val;
}
static uint16_t load16_align1(const uint16_t *ptr) {
    uint16_t val;
    memcpy(&val, ptr, sizeof(val));
    return val;
}
static uint32_t load32_align0(const uint8_t *ptr) {
    uint32_t val;
    memcpy(&val, ptr, sizeof(val));
    return val;
}
static uint32_t load32_align1(const uint16_t *ptr) {
    uint32_t val;
    memcpy(&val, ptr, sizeof(val));
    return val;
}
static uint32_t load32_align2(const uint32_t *ptr) {
    uint32_t val;
    memcpy(&val, ptr, sizeof(val));
    return val;
}
static uint64_t load64_align0(const uint8_t *ptr) {
    uint64_t val;
    memcpy(&val, ptr, sizeof(val));
    return val;
}
static uint64_t load64_align1(const uint16_t *ptr) {
    uint64_t val;
    memcpy(&val, ptr, sizeof(val));
    return val;
}
static uint64_t load64_align2(const uint32_t *ptr) {
    uint64_t val;
    memcpy(&val, ptr, sizeof(val));
    return val;
}
static uint64_t load64_align3(const uint64_t *ptr) {
    uint64_t val;
    memcpy(&val, ptr, sizeof(val));
    return val;
}

static uint32_t i32_popcnt(uint32_t lhs) {
    lhs = lhs - ((lhs >> 1) & UINT32_C(0x55555555));
    lhs = (lhs & UINT32_C(0x33333333)) + ((lhs >> 2) & UINT32_C(0x33333333));
    lhs = (lhs + (lhs >> 4)) & UINT32_C(0x0F0F0F0F);
    return (lhs * UINT32_C(0x01010101)) >> 24;
}
static uint32_t i32_ctz(uint32_t lhs) {
    return i32_popcnt(~lhs & (lhs - 1));
}
static uint32_t i32_clz(uint32_t lhs) {
    lhs = i32_byteswap(lhs);
    lhs = (lhs & UINT32_C(0x0F0F0F0F)) << 4 | (lhs & UINT32_C(0xF0F0F0F0)) >> 4;
    lhs = (lhs & UINT32_C(0x33333333)) << 2 | (lhs & UINT32_C(0xCCCCCCCC)) >> 2;
    lhs = (lhs & UINT32_C(0x55555555)) << 1 | (lhs & UINT32_C(0xAAAAAAAA)) >> 1;
    return i32_ctz(lhs);
}
static uint64_t i64_popcnt(uint64_t lhs) {
    lhs = lhs - ((lhs >> 1) & UINT64_C(0x5555555555555555));
    lhs = (lhs & UINT64_C(0x3333333333333333)) + ((lhs >> 2) & UINT64_C(0x3333333333333333));
    lhs = (lhs + (lhs >> 4)) & UINT64_C(0x0F0F0F0F0F0F0F0F);
    return (lhs * UINT64_C(0x0101010101010101)) >> 56;
}
static uint64_t i64_ctz(uint64_t lhs) {
    return i64_popcnt(~lhs & (lhs - 1));
}
static uint64_t i64_clz(uint64_t lhs) {
    lhs = i64_byteswap(lhs);
    lhs = (lhs & UINT64_C(0x0F0F0F0F0F0F0F0F)) << 4 | (lhs & UINT32_C(0xF0F0F0F0F0F0F0F0)) >> 4;
    lhs = (lhs & UINT64_C(0x3333333333333333)) << 2 | (lhs & UINT32_C(0xCCCCCCCCCCCCCCCC)) >> 2;
    lhs = (lhs & UINT64_C(0x5555555555555555)) << 1 | (lhs & UINT32_C(0xAAAAAAAAAAAAAAAA)) >> 1;
    return i64_ctz(lhs);
}

static void store16_align0(uint8_t *ptr, uint16_t val) {
    memcpy(ptr, &val, sizeof(val));
}
static void store16_align1(uint16_t *ptr, uint16_t val) {
    memcpy(ptr, &val, sizeof(val));
}
static void store32_align0(uint8_t *ptr, uint32_t val) {
    memcpy(ptr, &val, sizeof(val));
}
static void store32_align1(uint16_t *ptr, uint32_t val) {
    memcpy(ptr, &val, sizeof(val));
}
static void store32_align2(uint32_t *ptr, uint32_t val) {
    memcpy(ptr, &val, sizeof(val));
}
static void store64_align0(uint8_t *ptr, uint64_t val) {
    memcpy(ptr, &val, sizeof(val));
}
static void store64_align1(uint16_t *ptr, uint64_t val) {
    memcpy(ptr, &val, sizeof(val));
}
static void store64_align2(uint32_t *ptr, uint64_t val) {
    memcpy(ptr, &val, sizeof(val));
}
static void store64_align3(uint64_t *ptr, uint64_t val) {
    memcpy(ptr, &val, sizeof(val));
}

static uint32_t i32_reinterpret_f32(const float src) {
    uint32_t dst;
    memcpy(&dst, &src, sizeof(dst));
    return dst;
}
static uint64_t i64_reinterpret_f64(const double src) {
    uint64_t dst;
    memcpy(&dst, &src, sizeof(dst));
    return dst;
}
static float f32_reinterpret_i32(const uint32_t src) {
    float dst;
    memcpy(&dst, &src, sizeof(dst));
    return dst;
}
static double f64_reinterpret_i64(const uint64_t src) {
    double dst;
    memcpy(&dst, &src, sizeof(dst));
    return dst;
}

static uint32_t memory_grow(uint8_t **m, uint32_t *p, uint32_t *c, uint32_t n) {
    uint8_t *new_m = *m;
    uint32_t r = *p;
    uint32_t new_p = r + n;
    if (new_p > UINT32_C(0x10000)) return UINT32_C(0xFFFFFFF);
    uint32_t new_c = *c;
    if (new_c < new_p) {
        do new_c += new_c / 2 + 8; while (new_c < new_p);
        if (new_c > UINT32_C(0x10000)) new_c = UINT32_C(0x10000);
        new_m = realloc(new_m, new_c << 16);
        if (new_m == NULL) return UINT32_C(0xFFFFFFF);
        *m = new_m;
        *c = new_c;
    }
    *p = new_p;
    memset(&new_m[r << 16], 0, n << 16);
    return r;
}

static int inited;
static void init_elem(void);
static void init_data(void);
static void init(void) {
    if (inited != 0) return;
    init_elem();
    init_data();
    inited = 1;
}