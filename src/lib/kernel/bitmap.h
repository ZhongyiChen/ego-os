#ifndef __LIB_KERNEL_BITMAP_H
#define __LIB_KERNEL_BITMAP_H

#include "global.h"
#include "stdint.h"

#define BITMAP_MASK 1

/**
 * 位图结构体
 */
struct bitmap {
    // 位图所占字节长度
    uint32_t btmp_bytes_len;
    // 位图字节数组
    uint8_t* bits;
};

void init_bitmap(struct bitmap* btmp);
bool test_scan_bitmap(struct bitmap* btmp, uint32_t bit_idx);
int scan_bitmap(struct bitmap* btmp, uint32_t n);
void set_bitmap(struct bitmap* btmp, uint32_t bit_idx, int8_t value);

#endif
