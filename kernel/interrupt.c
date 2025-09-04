#include "interrupt.h"
#include "stdint.h"
#include "global.h"
#include "io.h"
#include "print.h"

#define PIC_M_CTRL 0x20					 	// 8259A 主片控制端口
#define PIC_M_DATA 0x21					 	// 8259A 主片数据端口
#define PIC_S_CTRL 0xa0					 	// 8259A 从片控制端口
#define PIC_S_DATA 0xa1					 	// 8259A 从片数据端口

#define IDT_DESC_N 0x21					 	// 当前支持的全部中断数量

/**
 * 中断门描述符结构体
 */
struct GateDesc {
	uint16_t fn_offset_low_word;			// 中断处理程序偏移地址低 16 位
	uint16_t selector;						// 中断处理程序目标代码段描述符选择子
	uint8_t dcount;							// 双字计数字段，对标门描述符的第 4 字节。在中断门描述符，此项固定值，不用考虑
	uint8_t attribute;						// 从低到高包括：TYPE(D110) + S(0_0000) + DPL(00_0_0000) + P(1_00_0_0000)
	uint16_t fn_offset_high_word;			// 中断处理程序偏移地址高 16 位
};

static void make_idt_desc(struct GateDesc* p_gdesc, uint8_t attr, intr_handler fn);
static struct GateDesc idt[IDT_DESC_N];		// idt 是中断描述符表，本质上就是个中断门描述符数组

extern intr_handler intr_entry_table[IDT_DESC_N];						// 声明引用定义在 kernel.S 中的中断处理函数入口数组

/**
 * 初始化可编程中断控制器(8259A)
 */
static void init_pic(void) {
	/** 初始化主片 */
	outb(PIC_M_CTRL, 0x11);					// ICW1: 边沿触发，级联 8259，需要 ICW4
	outb(PIC_M_DATA, 0x20);					// ICW2: 起始中断向量号为 0x20，也就是 IR[0-7] 为 0x20 ~ 0x27
	outb(PIC_M_DATA, 0x04);					// ICW3: 设置主从级联时用到的引脚为 IR2
	outb(PIC_M_DATA, 0x01);					// ICW4: 8086 模式，使用正常的 EOI
	
	/** 初始化从片 */
	outb(PIC_S_CTRL, 0x11);					// ICW1: 边沿触发，级联 8259，需要 ICW4
	outb(PIC_S_DATA, 0x28);					// ICW2: 起始中断向量号为 0x28，也就是 IR[8-15] 为 0x28 ~ 0x2F
	outb(PIC_S_DATA, 0x02);					// ICW3: 设置从片连接在主片的引脚为 IR2
	outb(PIC_S_DATA, 0x01);					// ICW4: 8086 模式，使用正常的 EOI
	
	/** 打开主片 IR0，即只接受时钟产生的中断 */
	outb(PIC_M_DATA, 0xfe);					// OCW1: 往 IMR 寄存器中发送的命令控制字，只让这片第 0 位为 0，即不屏蔽时钟中断
	outb(PIC_S_DATA, 0xff);					// OCW1: 屏蔽从片所有外设中断

	put_str("	init_pic done\n");
}

/**
 * 创建中断门描述符
 */
static void make_idt_desc(struct GateDesc* p_gdesc, uint8_t attr, intr_handler fn) {
	p_gdesc->fn_offset_low_word = (uint32_t)fn & 0x0000FFFF;
	p_gdesc->selector = SELECTOR_K_CODE;
	p_gdesc->dcount = 0;
	p_gdesc->attribute = attr;
	p_gdesc->fn_offset_high_word = ((uint32_t)fn & 0xFFFF0000) >> 16;
}

/**
 * 初始化中断描述符表
 */
static void init_idt_desc(void) {
	for (int i = 0; i < IDT_DESC_N; i++) {
		make_idt_desc(&idt[i], IDT_DESC_ATTR_DPL0, intr_entry_table[i]);
	}
	put_str("	init_idt_desc done\n");
}

/**
 * 初始化全部有关中断的工作
 */
void init_idt() {
	put_str("init_idt start\n");
	
	init_idt_desc();						// 初始化中断描述符表
	init_pic();								// 初始化可编程中断控制器(8259A)

	uint64_t idt_operand = (sizeof(idt) - 1) | ((uint64_t)(uint32_t)idt << 16);			// 低 16 位是 IDT 的界限（即表的大小减 1），高 32 位是 IDT 的基地址
	asm volatile("lidt %0" : : "m" (idt_operand));										//  lidt 只在该地址处（&idt_operand）取其中的 48 位数据当作操作数

	put_str("init_idt done\n");
}
