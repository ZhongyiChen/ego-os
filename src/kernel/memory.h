#ifndef __KERNEL_MEMORY_H
#define __KERNEL_MEMORY_H

#include "stdint.h"
#include "bitmap.h"

/**
 * 虚拟地址池，用于虚拟地址管理
 */
struct virtual_addr {
    // 虚拟地址需要用到的位图结构
    struct bitmap vaddr_bitmap;
    // 虚拟地址起始地址
    uint32_t vaddr_start;
};

/**
 * 对外暴露内核内存池和用户内存池
 */
extern struct pool kernel_pool, user_pool;

void init_mem(void);

#endif
