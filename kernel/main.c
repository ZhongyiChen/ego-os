#include "print.h"
#include "init.h"

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

    asm volatile("sti");                                    // 临时打开中断 Flag，以演示中断处理
    while(1);
}