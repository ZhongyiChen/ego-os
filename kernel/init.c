#include "init.h"
#include "print.h"
#include "interrupt.h"
#include "timer.h"

/**
 * 初始化所有模块
 */
void init_all() {
    put_str("init_all\n");
    init_idt();                     // 初始化中断设置
    init_timer();                   // 初始化 PIT
}
