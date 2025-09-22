#ifndef __THREAD_THREAD_H
#define __THREAD_THREAD_H

#include "stdint.h"

/**
 * 自定义通用函数类型（它将在很多线程函数中作为形参类型）
 */
typedef void thread_fn(void*);

/**
 * 进程或线程的状态
 */
enum TaskStatus {
    TASK_RUNNING,
    TASK_READY,
    TASK_BLOCKED,
    TASK_WAITING,
    TASK_HANGING,
    TASK_DIED
};

/**
 * 中断栈
 * 
 * 此结构用于中断发生时保护程序(线程或进程)的上下文环境。
 * 进程或线程被外部中断或软中断打断时，会按照此结构压入上下文寄存器。
 * 此栈在线程自己的内核栈中位置固定，即所在页的最顶端。
 */
struct IntrStack {
    // kernel.S 宏 VECTOR 中 push %1 压入的中断号
    uint32_t vec_no;
    uint32_t edi;
    uint32_t esi;
    uint32_t ebp;
    // pushad 把 ESP 也压入，但 ESP 是不断变化的,所以会被 popad 忽略
    uint32_t esp_dummy;
    uint32_t ebx;
    uint32_t edx;
    uint32_t ecx;
    uint32_t eax;
    uint32_t gs;
    uint32_t fs;
    uint32_t es;
    uint32_t ds;

    /* 以下由 CPU 从低特权级进入高特权级时压入 */

    // 错误码会被压入在 EIP 之后
    uint32_t err_code;
    void (*eip) (void);
    uint32_t cs;
    uint32_t eflags;
    void* esp;
    uint32_t ss;
};

/**
 * 线程栈
 * 
 * 用于存储线程中待执行的函数。
 * 此结构在线程自己的内核栈中位置不固定。
 * 用在 switch_to 时保存线程环境。
 * 实际位置取决于实际运行情况。
 */
struct ThreadStack {
    uint32_t ebp;
    uint32_t ebx;
    uint32_t edi;
    uint32_t esi;
    // 线程第一次执行时，EIP 指向待调用的函数 kernel_thread 
    // 其它时候，EIP 是指向 switch_to 的返回地址
    void (*eip) (thread_fn* fn, void* fn_arg);
    // 参数 unused_ret 只为占位置(作为返回地址)
    void (*unused_retaddr);
    // 由 kernel_thread 所调用的函数名
    thread_fn* fn;
    // 由 kernel_thread 所调用的函数所需的参数
    void* fn_arg;
};

/**
 * 进程或线程的 PCB（程序控制块）
 */
struct TaskStruct {
    // 各内核线程都用自己的内核栈
    uint32_t* self_kstack;
    enum TaskStatus status;
    // 线程优先级
    uint8_t priority;
    char name[16];
    // 用这串数字做栈的边界标记，用于检测栈的溢出
    uint32_t stack_magic;
};

void create_thread(struct TaskStruct* pthread, thread_fn fn, void* fn_arg);
void init_thread(struct TaskStruct* pthread, char* name, int prio);
struct TaskStruct* start_thread(char* name, int prio, thread_fn fn, void* fn_arg);

#endif
