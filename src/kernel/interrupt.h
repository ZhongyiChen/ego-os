#ifndef __KERNEL_INTERRUPT_H
#define __KERNEL_INTERRUPT_H

typedef void* intr_handler;
void init_idt(void);

/**
 * 中断状态
 */
enum IntrStatus {
    // 中断关闭
    INTR_OFF,
    // 中断打开
    INTR_ON
};

enum IntrStatus enable_intr(void);
enum IntrStatus disable_intr(void);
enum IntrStatus get_intr_status(void);
enum IntrStatus set_intr_status(enum IntrStatus status);

#endif
