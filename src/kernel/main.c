#include "print.h"
#include "init.h"
#include "debug.h"
#include "memory.h"
#include "thread.h"
#include "stdint.h"

void k_thread_a(void*);

void main(void) {
    put_char('\n');
    put_int(13579);
    put_char('\n');
    put_int(24680);
    put_char('\n');
    put_hex(0xA16809FE);
    put_char('\n');
    put_char('\n');

    put_char('k');
    put_char('e');
    put_char('r');
    put_char('n');
    put_char('e');
    put_char('l');
    put_char('1');
    put_char('2');
    put_char('\b');
    put_char('3');
    put_char('\n');
    put_char('\n');
    
    put_str("Hello World!\n");
    init_all();

    // asm volatile("sti");                                    // 临时打开中断 Flag，以演示中断处理
    // ASSERT(1 == 2);

    // void* addr = get_kernel_pages(3);
    // put_str("\nget_kernel_pages start vaddr is: ");
    // put_hex((uint32_t)addr);
    // put_str("\n");

    start_thread("k_thread_a", 31, k_thread_a, "argA ");

    while(1);
}

void k_thread_a(void* arg) {
    // 用 void* 来通用表示参数，被调用的函数知道自己需要什么类型的参数，自己转换再用
    char* param = arg;
    while (1) {
        put_str(param);
    }
}
