#include "memory.h"
#include "bitmap.h"
#include "global.h"
#include "debug.h"
#include "print.h"
#include "string.h"
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
 * 于最后一个页目录项保存的正是页目录表物理地址，即第 1023 个 pde
 * 
 * 1023 换算成十六进制是 0x3ff，将其移到高 10 后，变成 0xffc00000
 */
#define PDE_IDX(addr)   ((addr & 0xffc00000) >> 22)
#define PTE_IDX(addr)   ((addr & 0x003ff000) >> 12)

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
 * 在 pf 表示的虚拟内存池中申请 pg_n 个虚拟页
 * 
 * 成功则返回虚拟页的起始地址，失败则返回 NULL
 */
static void* get_vaddr(enum pool_flags pf, uint32_t pg_n) {
    int vaddr_start = 0;
    int bit_idx_start = -1;
    uint32_t n = 0;
    if (pf == PF_KERNEL) {
        // 内核内存池
        bit_idx_start = scan_bitmap(&kernel_vaddr.vaddr_bitmap, pg_n);
        if (-1 == bit_idx_start) {
            return NULL;
        }
        while (n < pg_n) {
            set_bitmap(&kernel_vaddr.vaddr_bitmap, bit_idx_start + n++, 1);
        }
        vaddr_start = kernel_vaddr.vaddr_start + bit_idx_start * PG_SIZE;
    } else {
        // 用户内存池，待实现
    }
    return (void*)vaddr_start;
}

/**
 * 获取虚拟地址 vaddr 对应的 pte 页表项指针
 */
uint32_t* pte_ptr(uint32_t vaddr) {
    // 0xffc00000 是页表区域的起始地址
    // 0xffc00000 也是一个掩码，提取虚拟地址的高 10 位（页目录索引）
    // 乘以 4 是因为每个页表项占 4 字节
    uint32_t* pte = (uint32_t*)(0xffc00000 + ((vaddr & 0xffc00000) >> 10) + PTE_IDX(vaddr) * 4);

    return pte;
}

/**
 * 获取虚拟地址 vaddr 对应的 pde 页目录项指针
 */
uint32_t* pde_ptr(uint32_t vaddr) {
    // 0xfffff000 是页目录表被映射到的固定虚拟地址，即最后一个页目录项（最后一个页目录项中存储的是页目录 表物理地址）
    // 乘以 4 是因为每个页目录项占 4 字节
    uint32_t* pde = (uint32_t*)(0xfffff000 + PDE_IDX(vaddr) * 4);

    return pde;
}

/**
 * 在 m_pool 指向的物理内存池中分配 1 个物理页
 * 
 * 成功则返回页框的物理地址，失败则返回 NULL
 */
static void* palloc(struct pool* m_pool) {
    int bit_idx = scan_bitmap(&m_pool->pool_bitmap, 1);
    if (-1 == bit_idx) {
        return NULL;
    }
    set_bitmap(&m_pool->pool_bitmap, bit_idx, 1);
    uint32_t page_phyaddr = bit_idx * PG_SIZE + m_pool->phy_addr_start;
    return (void*)page_phyaddr;
}

/**
 * 在页表中添加虚拟地址 vaddr 与物理地址 page_phyaddr 的映射
 */
static void page_table_add(void* vaddr, void* page_phyaddr) {
    uint32_t _vaddr = (uint32_t)vaddr;
    uint32_t _page_phyaddr = (uint32_t)page_phyaddr;
    uint32_t* pde = pde_ptr(_vaddr);
    uint32_t* pte = pte_ptr(_vaddr);

    if (*pde & 0x00000001) {
        // 先在页目录内判断目录项的 P 位，若为 1，则表示该表已存在
        // 页目录项和页表项的第 0 位为 P 位
        ASSERT(!(*pte & 0x00000001));

        if (!(*pte & 0x00000001)) {
            // US=1, RW=1, P=1
            *pte = _page_phyaddr | PG_US_U | PG_RW_w | PG_P_1;
        } else {
            PANIC("pte repeat");
            *pte = _page_phyaddr | PG_US_U | PG_RW_w | PG_P_1;
        }
        return;
    }
    // 来到这里表示页目录项不存在，要先创建页目录再创建页表项
    // 页表中用到的页框一律从内核空间分配
    uint32_t _pde_phyaddr = (uint32_t)palloc(&kernel_pool);
    *pde = _pde_phyaddr | PG_US_U | PG_RW_w | PG_P_1;
    // 分配到的物理页地址 pde_phyaddr 对应的物理内存清 0
    // 访问到 pde 对应的物理地址,用 pte 取高 20 位便可
    // 把低 12 位置 0 便是该 pde 对应的物理页的起始
    memset((void*)((int)pte & 0xfffff000), 0, PG_SIZE);
    ASSERT(!(*pte & 0x00000001));
    *pte = _page_phyaddr | PG_US_U | PG_RW_w | PG_P_1;
}

/**
 * 分配 pg_n 个页空间
 * 
 * 成功则返回起始虚拟地址，失败则返回 NULL
 */
void* malloc_page(enum pool_flags pf, uint32_t pg_n) {
    // 15 * 1024 * 1024 / 4096 = 3840 页，即现在最大支持 15MB
    ASSERT(pg_n > 0 && pg_n < 3840);
    // malloc_page 的原理是三个动作的合成：
    // 1. 通过 get_vaddr 在虚拟内存池中申请虚拟地址
    // 2. 通过 palloc 在物理内存池中申请物理页
    // 3. 通过 page_table_add 将以上得到的虚拟地址和物理地址在页表中完成映射
    void* vaddr_start = get_vaddr(pf, pg_n);
    if (NULL == vaddr_start) {
        return NULL;
    }
    uint32_t vaddr = (uint32_t)vaddr_start;
    uint32_t n = pg_n;
    struct pool* mem_pool = pf & PF_KERNEL ? &kernel_pool : &user_pool;

    while (n-- > 0) {
        void* page_phyaddr = palloc(mem_pool);
        if (NULL == page_phyaddr) {
            // 失败时要将曾经已申请的虚拟地址和物理页全部回滚，待实现
            return NULL;
        }
        page_table_add((void*)vaddr, page_phyaddr);
        vaddr += PG_SIZE;                                   // 指向下一个虚拟页
    }
    return vaddr_start;
    
}

/**
 * 从内核物理内存池中申请 pg_n 页内存
 * 
 * 成功则返回其虚拟地址，失败则返回 NULL
 */
void* get_kernel_pages(uint32_t pg_n) {
    void* vaddr = malloc_page(PF_KERNEL, pg_n);
    if (NULL != vaddr) {
        // 若分配的地址不为空，将页框清 0 后返回
        memset(vaddr, 0, pg_n * PG_SIZE);
    }
    return vaddr;
}

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
