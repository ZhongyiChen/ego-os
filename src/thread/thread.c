#include "thread.h"
#include "string.h"
#include "global.h"
#include "memory.h"
#include "stdint.h"

#define PG_SIZE 4096

/**
 * 由 kernel_thread 去执行 fn(fn_arg)
 */
static void kernel_thread(thread_fn* fn, void* fn_arg) {
    fn(fn_arg);
}

void create_thread(struct TaskStruct* pthread, thread_fn fn, void* fn_arg) {
    // 先预留中断使用栈的空间（参考 thread.h 中定义的结构）
    pthread->self_kstack -= sizeof(struct IntrStack);
    // 再留出线程栈空间（参考 thread.h 中定义的结构）
    pthread->self_kstack -= sizeof(struct ThreadStack);

    struct ThreadStack* kthread_stack = (struct ThreadStack*)pthread->self_kstack;

    kthread_stack->eip = kernel_thread;
    kthread_stack->fn = fn;
    kthread_stack->fn_arg = fn_arg;
    kthread_stack->ebp = kthread_stack->ebx = kthread_stack->esi = kthread_stack->edi = 0;
}

/**
 * 初始线程基本信息
 */
void init_thread(struct TaskStruct* pthread, char* name, int prio) {
    memset(pthread, 0, sizeof(*pthread));
    strcpy(pthread->name, name);
    pthread->status = TASK_RUNNING;
    pthread->priority = prio;
    // self_kstack 是线程自己在内核态下使用的栈顶地址
    pthread->self_kstack = (uint32_t*)((uint32_t)pthread + PG_SIZE);
    // 自定义的魔数
    pthread->stack_magic = 0x19870916;
}

/**
 * 创建一个优先级为 prio 的线程，线程名为 name，线程所执行的函数是 fn(fn_arg)
 */
struct TaskStruct* start_thread(char* name, int prio, thread_fn fn, void* fn_arg) {
    // PCB 都位于内核空间，包括用户进程的 PCB 也是在内核空间
    struct TaskStruct* thread = get_kernel_pages(1);
    init_thread(thread, name, prio);
    create_thread(thread, fn, fn_arg);
    asm volatile ("movl %0, %%esp; pop %%ebp; pop %%ebx; pop %%edi; pop %%esi; ret" : : "g" (thread->self_kstack) : "memory");
    return thread;
}
