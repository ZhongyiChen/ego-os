#include "bitmap.h"
#include "string.h"
#include "print.h"
#include "interrupt.h"
#include "debug.h"
#include "stdint.h"

/**
 * 初始化位图
 */
void init_bitmap(struct bitmap* btmp) {
    memset(btmp->bits, 0, btmp->btmp_bytes_len);
}

/**
 * 判断 bit_idx 位是否为 1
 * 
 * @return true/false
 */
bool test_scan_bitmap(struct bitmap* btmp, uint32_t bit_idx) {
    uint32_t byte_idx = bit_idx / 8;            // 找到 bit_idx 所在字节
    uint32_t bit_odd = bit_idx % 8;             // 取余获取 bit_idx 在所在字节的偏移位
    return (btmp->bits[byte_idx] & (BITMAP_MASK << bit_odd));
}

/**
 * 在位图中申请连续 n 个位，成功则返回其起始位下标，失败则返回 -1
 */
int scan_bitmap(struct bitmap* btmp, uint32_t n) {
    uint32_t byte_idx = 0;                      // 记录空闲位所在字节在位图的下标
    while ((0xff == btmp->bits[byte_idx]) && (byte_idx < btmp->btmp_bytes_len)) {
        byte_idx++;
    }
    ASSERT(byte_idx < btmp->btmp_bytes_len);
    if (byte_idx == btmp->btmp_bytes_len) {
        // 若该内存池找不到可用空间
        return -1;
    }
    int bit_idx = 0;                            // 记录空闲位在所在字节的下标
    while ((uint8_t)(BITMAP_MASK << bit_idx) & btmp->bits[byte_idx]) {
        bit_idx++;
    }
    int bit_idx_start = byte_idx * 8 + bit_idx; // 记录空闲位在位图内的下标
    if (1 == n) {
        return bit_idx_start;
    }
    uint32_t bit_left = (btmp->btmp_bytes_len * 8 - bit_idx_start);     // 记录剩余可判断位数
    uint32_t bit_next = bit_idx_start + 1;
    uint32_t count = 1;                         // 记录找到的空闲位个数

    bit_idx_start = -1;                         // 置 -1，若找不到连续位就直接返回
    while (bit_left-- > 0) {
        if (!(test_scan_bitmap(btmp, bit_next))) {
            // 若 bit_next 为 0
            count++;
        } else {
            count = 0;
        }
        if (count == n) {
            // 若找到了连续的 n 个空位
            bit_idx_start = bit_next - n + 1;
            break;
        }
        bit_next++;
    }
    return bit_idx_start;
}

/**
 * 将位图的 bit_idx 位设置为 value
 */
void set_bitmap(struct bitmap* btmp, uint32_t bit_idx, int8_t value) {
    ASSERT((value == 0) || (value == 1));
    uint32_t byte_idx = bit_idx / 8;            // 获取 bit_idx 位在位图的偏移字节
    uint32_t bit_odd = bit_idx % 8;             // 获取 bit_idx 位在所在字节的偏移位

    if (value) {
        btmp->bits[byte_idx] |= (BITMAP_MASK << bit_odd);
        return;
    }
    btmp->bits[byte_idx] &= ~(BITMAP_MASK << bit_odd);
}
