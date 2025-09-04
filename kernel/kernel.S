; 中断处理程序

[bits 32]

%define ERROR_CODE		nop								; 若在相关的异常中 CPU 已经自动压入错误码，则不做操作
%define ZERO			push 0							; 若在相关的异常中 CPU 没有压入错误码，则手动压入一个 0

extern put_str											; 声明外部引用

section .data
intr_str db "Interrupt occur!", 0xa, 0
global intr_entry_table									; 导出数组名，让其他文件可使用本数组
intr_entry_table:

%macro VECTOR 2
section .text
intr%1entry:
	%2
	push intr_str
	call put_str
	add esp,4											; 跳过第一个参数

	mov al,0x20											; 中断结束命令 EOI
	out 0xa0,al											; 给从片发送
	out 0x20,al											; 给主片发送

	add esp,4											; 跨过 ERROR_CODE，即第二个参数
	iret												; 从中断中返回，在 32 位模式下等同于 iretd
section .data
	dd intr%1entry										; 存储各个中断入口程序的地址，以形成 intr_entry_table 数组
														; 32 位下的地址是 4 字节
														; 编译器会将属性相同的 section 合并到同一个大的 segment 中
														; 因此经过编译器处理后，intr_entry_table 将会变成一个 dd 数组
%endmacro

; 中断向量 0～19 为处理器内部固定的异常类型，20～31 是 Intel 保留的
VECTOR 0x00,ZERO
VECTOR 0x01,ZERO
VECTOR 0x02,ZERO
VECTOR 0x03,ZERO
VECTOR 0x04,ZERO
VECTOR 0x05,ZERO
VECTOR 0x06,ZERO
VECTOR 0x07,ZERO
VECTOR 0x08,ERROR_CODE
VECTOR 0x09,ZERO
VECTOR 0x0a,ERROR_CODE
VECTOR 0x0b,ERROR_CODE
VECTOR 0x0c,ZERO
VECTOR 0x0d,ERROR_CODE
VECTOR 0x0e,ERROR_CODE
VECTOR 0x0f,ZERO
VECTOR 0x10,ZERO
VECTOR 0x11,ERROR_CODE
VECTOR 0x12,ZERO
VECTOR 0x13,ZERO
VECTOR 0x14,ZERO
VECTOR 0x15,ZERO
VECTOR 0x16,ZERO
VECTOR 0x17,ZERO
VECTOR 0x18,ERROR_CODE
VECTOR 0x19,ZERO
VECTOR 0x1a,ERROR_CODE
VECTOR 0x1b,ERROR_CODE
VECTOR 0x1c,ZERO
VECTOR 0x1d,ERROR_CODE
VECTOR 0x1e,ERROR_CODE
VECTOR 0x1f,ZERO
VECTOR 0x20,ZERO
