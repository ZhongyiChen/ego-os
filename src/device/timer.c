#include "timer.h"
#include "io.h"
#include "print.h"
#include "stdint.h"

#define IRQ0_FREQUENCY				100			// 8253 被期盼的中断频率
#define INPUT_FREQUENCY				1193180		// 8253 计算器的工作频率约为 1.19318MHz
#define COUNTER0_VALUE				INPUT_FREQUENCY / IRQ0_FREQUENCY
#define COUNTER0_PORT				0x40
#define COUNTER0_NO					0
#define COUNTER_MODE				2
#define READ_WRITE_LATCH			3
#define PIT_CONTROL_PORT			0x43

/**
 * 设置模式控制寄存器
 *
 * @param counter_port - 计数器端口
 * @param counter_no - (控制字中指定的)计数器序号
 * @param rwl - (控制字中指定的)读写锁属性
 * @param counter_mode - (控制字中指定的)计数器模式
 * @param counter_value - 计数器初始值
 */
static void set_frequency(uint8_t counter_port, uint8_t counter_no, uint8_t rwl, uint8_t counter_mode, uint16_t counter_value) {
	//  往控制字寄存器端口 0x43 中写入控制字
	outb(PIT_CONTROL_PORT, (uint8_t)(counter_no << 6 | rwl << 4 | counter_mode << 1));
	//  先写入 counter_value 的低 8 位
	outb(counter_port, (uint8_t)counter_value);
	//  再写入 counter_value 的高 8 位
	outb(counter_port, (uint8_t)counter_value >> 8);
}

/**
 * 初始化 PIT 8253
 */
void init_timer() {
	put_str("init_timer start\n");

	// 设置 8253 的定时周期，也就是触发中断的周期
	set_frequency(COUNTER0_PORT, COUNTER0_NO, READ_WRITE_LATCH, COUNTER_MODE, COUNTER0_VALUE);
	put_str("init_timer done\n");
}
