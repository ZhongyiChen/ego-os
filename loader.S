%include "include/boot.inc"
section loader vstart=LOADER_BASE_ADDR

	LOADER_STACK_TOP equ LOADER_BASE_ADDR

	jmp loader_start

;------------------ 1dq = 2dd = 4dw = 8db -------------------

	GDT_BASE:  			dd 0x00000000
						dd 0x00000000

   	CODE_DESC:  		dd 0x0000FFFF
                		dd DESC_CODE_HIGH4

   	DATA_STACK_DESC: 	dd 0x0000FFFF
                     	dd DESC_DATA_HIGH4

	VIDEO_DESC: 		dd 0x80000007						; limit = (0xBFFFF-0xB8000)/4k = 0x7 
                 		dd DESC_VIDEO_HIGH4  				; 记住此时 DPL 为 0 

	GDT_SIZE			equ $ - GDT_BASE
	GDT_LIMIT			equ GDT_SIZE - 1
	
	times 60 dq 0               							; 此处预留 60 个描述符的空位
															; times 是 nasm 提供的伪指令，用来重复执行 times 后面的表达式

	SELECTOR_CODE 		equ (0x0001<<3) + TI_GDT + RPL0		; 对应 GDT 的 CODE_DESC
	SELECTOR_DATA 		equ (0x0002<<3) + TI_GDT + RPL0		; 对应 GDT 的 DATA_STACK_DESC
	SELECTOR_VIDEO 		equ (0x0003<<3) + TI_GDT + RPL0		; 对应 GDT 的 VIDEO_DESC

	gdt_ptr  			dw  GDT_LIMIT
						dd  GDT_BASE
	loadermsg 			db '2 loader in real.'

loader_start:
;------------------------------------------------------------ 
; INT 0x10    功能号:0x13    功能描述:打印字符串
;------------------------------------------------------------ 
; 输入:
; 	AH = 子功能号(13H)
; 	BH = 页码
;	BL = 属性(若AL=00H或01H)
;	CX = 字符串长度
;	(DH､DL) = 坐标(行、列)
;	ES:BP = 字符串地址
;	AL = 显示输出方式
;  		 0 —— 字符串中只含显示字符，其显示属性在BL中；显示后，光标位置不变
;  		 1 —— 字符串中只含显示字符，其显示属性在BL中；显示后，光标位置改变
;  		 2 —— 字符串中含显示字符和显示属性。显示后，光标位置不变
;  		 3 —— 字符串中含显示字符和显示属性。显示后，光标位置改变
; 无返回值
    mov sp,LOADER_BASE_ADDR 
    mov bp,loadermsg    									; ES:BP = 字符串地址 
    mov cx,17            									; CX = 字符串长度 
    mov ax,0x1301        									; AH = 13,  AL = 01h 
    mov bx,0x001f         									; 页号为 0(BH = 0) 蓝底粉红字(BL = 1fh) 
    mov dx,0x1800           								; 行数 dh 为 0x18，列数 dl 为 0x00。0x18 的十进制为 24，即最后一行行首
    int 0x10                 								; 最后一次调用 10h 号中断

;--------------------   准备进入保护模式   ------------------------------- 
; 1 打开 A20 
; 2 加载 gdt 
; 3 将 cr0 的 pe 位置 1
;------------------------------------------------------------------------

;--------------------        打开A20      -------------------------------
	in al,0x92
	or al,0000_0010B										; 端口 0x92 的第 1 位置置 1，表示打开 A20Gate
	out 0x92,al

;--------------------       加载 GDT      -------------------------------
	lgdt [gdt_ptr]

;--------------------    cr0 第 0 位置 1  -------------------------------
	mov eax,cr0
	or eax,0x00000001										; PE(Protection Enable) 位置 1
	mov cr0,eax


;--------------------     强制刷新流水线   -------------------------------
	jmp dword SELECTOR_CODE:p_mode_start

[bits 32]

p_mode_start: 
	mov ax,SELECTOR_DATA
	mov ds,ax
	mov es,ax
	mov ss,ax
	mov esp,LOADER_STACK_TOP 
	mov ax,SELECTOR_VIDEO
	mov gs,ax

	mov byte [gs:160],'P'									; 默认的文本显示模式是 80*25，即每行是 80 个字符（0～79），每个字符占 2 字节
															; 所以这里的意思是在第 1 行(0 为首行)行首处显示后面的文本字符

	jmp $
