#ifndef __LIB_KERNEL_IO_H
#define __LIB_KERNEL_IO_H

#include "stdint.h"

/**
 * 向端口 port 写入 1 个字节
 */
static inline void outb(uint16_t port, uint8_t data) {
    // inline 关键字的作用是建议编译器将本函数编译为内嵌的方式（类似于宏，在调用该函数的地方原封不动地展开，从而避免 call 与 ret 命令）

    // a 表示寄存器 AL/AX/EAX
    // N 表示自然数 0 ~ 255
    // d 表示寄存器 DL/DX/EDX
    // b 表示寄存器中低部分 1 字节对应的名称，如 AL/BL/CL/DL
    // w 表示寄存器中大小为 2 字节对应的名称，如 AX/BX/CX/DX
    // %b0 表示对应 AL
    // %w1 表示对应 DX
    asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
}

/**
 * 向端口 port 写入 n 个字
 */
static inline void outsw(uint16_t port, const void* addr, uint32_t word_n) {
    // addr 被 const 修饰表示 “我只会读取这块内存，不会修改它”

    // + 表示该限制既做输入又做输出
    // S 表示寄存器 SI/ESI
    // c 表示寄存器 CL/CX/ECX
    
    // 这里的总体意思是：从 [DS:ESI] 读取数据，输出到 DX 指定的端口，然后 ESI 增加 2，直到 ECX 递减至 0
    asm volatile ("cld; rep outsw" : "+S" (addr), "+c" (word_n) : "d" (port));
}

/**
 * 从端口 port 读入 1 个字节
 */
static inline uint8_t inb(uint16_t port) {
    uint8_t data;

    // = 表示只写，这里意味着 AX 只能被汇编指令写入，即作为结果容器
    asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));

    return data;
}

/**
 * 从端口 port 读入 n 个字节并写入到 addr 指向的内存块
 */
static inline void insw(uint16_t port, void* addr, uint32_t word_n) {
    // addr 没被 const 修饰表示 “本函数会修改这块内存的数据”

    // D 表示寄存器 DI/EDI
    // memory 表示汇编代码修改了内存，也表示 CPU 每次访问变量时老老实实地从内存中获取(而不是从寄存器缓存中获取)

    // 这里的总体意思是：从 DX 指定的端口中获取数据(一个字)，写入到 [ES:EDI] 指向的内存，然后 EDI 增加 2，直到 ECX 递减至 0
    asm volatile ("cld; rep insw" : "+D" (addr), "+c" (word_n) : "d" (port) : "memory");
}

#endif
