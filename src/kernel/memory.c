#include "memory.h"
#include "print.h"
#include "stdint.h"

#define PG_SIZE 4096

/**
 * 0xc009f000 是内核主线程栈顶
 * 0xc009e000 是内核主线程的 PCB
 * 一个页框大小的位图可表示 128MB 内存
 * 将位图位置安排在地址 0xc009a000，这样本系统最大支持 4 个页框的位图(即 512MB)
 */
#define MEM_BITMAP_BASE 0xc009a000

/**
 * 0xc0000000 是内核从虚拟地址 3GB 起点
 * 0x100000 意指跨过低端 1MB 内存，使虚拟地址在逻辑上连续
 */
#define K_HEAP_START    0xc0100000

/**
 * 内存池结构
 */
struct pool {
    // 本内存池用到的位图结构，用于管理物理内存
    struct bitmap pool_bitmap;
    // 本内存池所管理物理内存的起始地址
    uint32_t phy_addr_start;
    // 本内存池字节容量
    uint32_t pool_size;
};

/**
 * 生成两个实例用于管理内核内存池和用户内存池
 */
struct pool kernel_pool, user_pool;

/**
 * 用于内核分配虚拟地址
 */
struct virtual_addr kernel_vaddr;

/**
 * 初始化内存池
 */
static void init_mem_pool(uint32_t all_mem) {
    put_str("init_mem_pool start\n");

    uint32_t page_table_size = PG_SIZE * 256;                       // 页表大小 = 1 页的页目录表 + 第 0 和第 768 页目录项指向同一个页表 + 第 769 ~ 1022 个页目录项（共 254 个页表
    uint32_t used_mem = page_table_size + 0x100000;                 // 0x100000 表示低端 1MB 内存
    uint32_t free_mem = all_mem - used_mem;
    uint16_t all_free_pages = free_mem / PG_SIZE;                   // 1 页为 4KB，因此不管剩余总内存是不是 4KB 的倍数
    uint16_t kernel_free_pages = all_free_pages / 2;
    uint16_t user_free_pages = all_free_pages - kernel_free_pages;

    uint32_t kbm_length = kernel_free_pages / 8;                    // Kernel Bitmap 的长度（位图中的 1 bit 表示一页）
    uint32_t ubm_length = user_free_pages / 8;                      // User Bitmap 的长度

    uint32_t kp_start = used_mem;                                   // Kernel Pool 内核内存池的起始地址
    uint32_t up_start = kp_start + kernel_free_pages * PG_SIZE;     // User Pool 用户内存池的起始地址

    kernel_pool.phy_addr_start = kp_start;
    kernel_pool.pool_size = kernel_free_pages * PG_SIZE;
    kernel_pool.pool_bitmap.btmp_bytes_len = kbm_length;
    kernel_pool.pool_bitmap.bits = (void*)MEM_BITMAP_BASE;

    user_pool.phy_addr_start = up_start;
    user_pool.pool_size = user_free_pages * PG_SIZE;
    user_pool.pool_bitmap.btmp_bytes_len = ubm_length;
    user_pool.pool_bitmap.bits = (void*)(MEM_BITMAP_BASE + kbm_length);     // 用户内存池的位图紧跟在内核内存池位图之后

    put_str("    kernel_pool_bitmap_start: ");
    put_hex((int)kernel_pool.pool_bitmap.bits);
    put_str("\n");
    put_str("    kernel_pool_bitmap_end: ");
    put_hex((int)kernel_pool.pool_bitmap.bits + kernel_pool.pool_bitmap.btmp_bytes_len);
    put_str("\n");
    put_str("    kernel_pool_phy_addr_start: ");
    put_hex(kernel_pool.phy_addr_start);
    put_str("\n");
    put_str("    kernel_pool_phy_addr_end: ");
    put_hex(kernel_pool.phy_addr_start + kernel_pool.pool_size);
    put_str("\n");
    put_str("\n");
    put_str("    user_pool_bitmap_start: ");
    put_hex((int)user_pool.pool_bitmap.bits);
    put_str("\n");
    put_str("    user_pool_bitmap_end: ");
    put_hex((int)user_pool.pool_bitmap.bits + user_pool.pool_bitmap.btmp_bytes_len);
    put_str("\n");
    put_str("    user_pool_phy_addr_start: ");
    put_hex(user_pool.phy_addr_start);
    put_str("\n");
    put_str("    user_pool_phy_addr_end: ");
    put_hex(user_pool.phy_addr_start + user_pool.pool_size);
    put_str("\n");
    put_str("\n");

    // 将位图置 0
    init_bitmap(&kernel_pool.pool_bitmap);
    init_bitmap(&user_pool.pool_bitmap);

    // 下面初始化内核虚拟地址的位图，按实际物理内存大小生成数组
    // 用于维护内核堆的虚拟地址，所以要和内核内存池大小一致
    kernel_vaddr.vaddr_bitmap.btmp_bytes_len = kbm_length;

    // 位图的数组指向一块未使用的内存，目前定位在内核内存池和用户内存池之外
    kernel_vaddr.vaddr_bitmap.bits = (void*)(MEM_BITMAP_BASE + kbm_length + ubm_length);
    kernel_vaddr.vaddr_start = K_HEAP_START;

    put_str("    kernel_vaddr.vaddr_bitmap.start: ");
    put_hex((int)kernel_vaddr.vaddr_bitmap.bits);
    put_str("\n");
    put_str("    kernel_vaddr.vaddr_bitmap.end: ");
    put_hex((int)kernel_vaddr.vaddr_bitmap.bits + kernel_vaddr.vaddr_bitmap.btmp_bytes_len);
    put_str("\n");
    put_str("\n");

    init_bitmap(&kernel_vaddr.vaddr_bitmap);

    put_str("init_mem_pool done\n");
}

/**
 * 内存管理部分初始化入口
 */
void init_mem() {
    put_str("init_mem start\n");
    uint32_t mem_bytes_total = *((uint32_t*)0xb00);
    init_mem_pool(mem_bytes_total);                             // 初始化内存池
    put_str("init_mem done\n");
}
