%include "../include/boot.inc"
section loader vstart=LOADER_BASE_ADDR

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

	; total_mem_bytes 用于保存内存容量，以字节为单位，此位置比较好记
	; 当前偏移 loader.bin 文件头 0x200 字节，而 loader.bin 的加载地址是 0x900
	; 所有 total_mem_bytes 在内存中的地址是 0xb00 (在内核中会引用此地址)
	total_mem_bytes 	dd 0

	; GDT 指针，前 2 字节是 GDT 界限，后 4 字节是 GDT 起始地址
	gdt_ptr  			dw  GDT_LIMIT
						dd  GDT_BASE

	; ARDS(结构体本身是 20 字节大小，这里使用 228 是为了使 loader_start 对齐 256 字节)
	ards_buf times 228	db 0
	ards_n				dw 0

	ch_table			db '0123456789abcdef'

loader_start:

;-----------------------------------------------------------------------
; INT 0x15    功能号: 0xE820 | 0xE801 | 0x88       功能描述:获取内存大小
;-----------------------------------------------------------------------
	xor ebx,ebx												; 第一次调用时必须把 EBX 置 0
	mov edx,0x534d4150										; 'SMAP' 的 ASCII 码
	mov di,ards_buf											; [ES:DI] 指向 ARDS 结构缓冲区
	
	.e820_mem_get_loop:
		mov eax,0x0000e820									; 设置子功能号 AX = 0xE820
		mov ecx,20											; ARDS 结构体大小，默认是 20 字节
		int 0x15
		jc .e820_failed_so_try_e801   						; 若 CF 位为 1 则有错误发生，尝试 0xE801 子功能
		add di,cx											; 当前内存块信息已获取成功，指向下一个 ARDS 结构体位置
		inc word [ards_n]									; ARDS 结构体总数量 + 1
		cmp ebx,0											; 判断是否已经全部读取：若 EBX 为 0 且 CF 不为 1，说明 ARDS 信息已全部返回
		jnz .e820_mem_get_loop

		mov cx,[ards_n]										; 准备遍历每一个 ARDS 结构体，找出 base_add_low + length_low 的最大值，即内存容量
		mov ebx,ards_buf
		xor edx,edx											; EDX 用于表示最大的内存容量
	
	.find_max_mem_area:
		mov eax,[ebx]										; [EBX] = base_add_low
		add eax,[ebx + 8]									; [EBX + 8] = length_low
		add ebx,20											; 指向下一个 ARDS 结构体
		cmp edx,eax											; 找出最大值，然后放置于 EDX 中
		jge .next_ards
		mov edx,eax
	.next_ards:
		loop .find_max_mem_area
		jmp .mem_get_ok

	.e820_failed_so_try_e801:
		mov ax,0xe801										; 设置子功能号 AX = 0xE801
		int 0x15
		jc .e801_failed_so_try88							; 当前 0xE801 方法失败，最后尝试 0x88 方法

		mov cx,0x400										; 0x400 = 1KB
		mul cx												; DX:AX = AX * CX
		shl edx,16											; DX 移至 EDX 高 16 位，DX 清零
		and eax,0x0000FFFF									; EAX 高 16 位清零
		or edx,eax											; EDX 表示着低 15MB 的内存大小
		add edx,0x100000									; 加上无法获取的那 1MB
		mov esi,edx											; 把此低 15MB 的内存大小放置于 ESI 中，以作备份

		xor eax,eax											; EAX 高位清零。准备统计 16MB 以上的内存，此时 16MB 以上的总内存大小 = BX(或 DX) * 64KB
		mov ax,bx
		mov ecx,0x10000										; 0x10000 = 64KB
		mul ecx												; EDX:EAX = EAX * ECX
		add esi,eax											; 当前只为检测 4GB 以内的内存，因此直接忽略 EDX
		mov edx,esi											; EDX 就是最终的总内存大小
		jmp .mem_get_ok

	.e801_failed_so_try88:
		mov ah,0x88											; 设置子功能号 AH = 0x88
		int 0x15
		jc .error_hlt
		add eax,0x0000ffff									; 总容量 = AX * 1KB，EAX 高 16 位直接清零

		mov cx,0x400										; 0x400 = 1KB
		mul cx												; DX:AX = AX * CX
		shl edx,16											; DX 移至 EDX 高 16 位，DX 清零
		or edx,eax											; EDX 表示着结果内存的大小
		add edx,0x100000									; 0x88 子功能也只会返回 1MB 以上的内存，因此实际内存必须加上该尺寸

	.mem_get_ok:
		mov [total_mem_bytes],edx							; 最终将内存大小存放于 total_mem_bytes

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
    mov bp,ch_table    										; ES:BP = 字符串地址 
    mov cx,16            									; CX = 字符串长度 
    mov ax,0x1301        									; AH = 13,  AL = 01h 
    mov bx,0x001f         									; 页号为 0(BH = 0) 蓝底粉红字(BL = 1fh) 
    mov dx,0x1800           								; 行数 DH 为 0x18，列数 DL 为 0x00。0x18 的十进制为 24，即最后一行行首
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
	or eax,0x00000001										; PE(Protection Enable) 位，置 1
	mov cr0,eax


;--------------------     强制刷新流水线   -------------------------------
	jmp dword SELECTOR_CODE:p_mode_start

;--------------------     出现错误即挂起   -------------------------------
.error_hlt:
	hlt

[bits 32]

p_mode_start: 
	mov ax,SELECTOR_DATA
	mov ds,ax
	mov es,ax
	mov ss,ax
	mov esp,LOADER_STACK_TOP 
	mov ax,SELECTOR_VIDEO
	mov gs,ax

	mov eax,KERNEL_START_SECTOR								; EAX 指向 kernel.bin 所在的磁盘扇区号
	mov ebx,KERNEL_BIN_BASE_ADDR							; EBX 指向 kernel.bin 将被搬至的内存起始地址
	mov ecx,200												; ECX 指定需要读取的扇区数（与 dd 命令的 count 参数值一致）
	call rd_disk_m_32										; 调用（32 位模式下）读取磁盘的函数

	call setup_page											; 创建页目录及页表，并初始化页内存位图

	sgdt [gdt_ptr]											; 将 GDT 的位置先保存起来

	mov ebx,[gdt_ptr + 2]									; 将 GDT_BASE 放置于 EBX 中
	or dword [ebx + 0x18 + 4],0xc0000000					; 视频段是第 3 个段描述符,每个描述符是 8 字节,故这里加上 0x18；加 4 则表示指向段描述符的高 4 字节
															; 0xc0000000 是内存 3GB 起始处。下同
	
	add dword [gdt_ptr + 2],0xc0000000						; 使 GDT_BASE 加上 3GB，以符合内核位置要求
	add esp,0xc0000000										; 栈指针亦映射到内核地址

	mov eax,PAGE_DIR_TABLE_POS
	mov cr3,eax												; 把页目录地址赋给 CR3

	mov eax,cr0
	or eax,0x80000000										; 打开 CR0 的 PG 位（第 31 位）
	mov cr0,eax												; 分页已开启

	lgdt [gdt_ptr]											; 用新的地址加载 GDT

	mov byte [gs:160],'L'									; 默认的文本显示模式是 80*25，即每行是 80 个字符（0～79），每个字符占 2 字节
															; 所以这里的意思是在第 1 行(0 为首行)行首处显示后面的文本字符

	jmp SELECTOR_CODE:enter_kernel	  						; 再次强制刷新流水线，以更新 GDT


;------------------------------------------------------------ 
; 进入内核，即运行 kernel.bin
;------------------------------------------------------------ 
enter_kernel:
	mov byte [gs:320], 'k'									; 视频段段基址已经被更新（下同）
	mov byte [gs:322], 'e'
	mov byte [gs:324], 'r'
	mov byte [gs:326], 'n'
	mov byte [gs:328], 'e'
	mov byte [gs:330], 'l'

	call kernel_init

	mov esp, 0xc009f000

	jmp KERNEL_ENTRY_POINT


;------------------------------------------------------------ 
; 将 kernel.bin 中的各个 segment 拷贝到待执行的虚拟地址
;------------------------------------------------------------ 
kernel_init:
	xor eax,eax
	xor ebx,ebx												; EBX 用于记录程序头表地址
	xor ecx,ecx												; CX 用于记录程序头表中的 Program Header 数量
	xor edx,edx												; DX 用于记录 Program Header 的尺寸，即 e_phentsize

	mov dx,[KERNEL_BIN_BASE_ADDR + 42]						; kernel.bin 偏移 42 字节处是 e_phentsize
	mov ebx,[KERNEL_BIN_BASE_ADDR + 28]						; kernel.bin 偏移 28 字节处是 e_phoff
	add ebx,KERNEL_BIN_BASE_ADDR							; EBX 指向 Program Header 的物理地址
	mov cx,[KERNEL_BIN_BASE_ADDR + 44]						; kernel.bin 偏移 44 字节处是 e_phnum

	.each_segment:
		cmp byte [ebx + 0],PT_NULL							; 若 p_type == PT_NULL，说明此 Program Header 未使用
		je .PTNULL

		; 为函数 mem_cpy 压入参数，顺序为从右往左。函数原型类似于 mem_cpy(dst, src, size)
		push dword [ebx + 16]								; Program Header 中偏移 16 字节处是 p_filesz
															; 参数 size
		mov eax,[ebx + 4]									; Program Header 中偏移 4 字节处是 p_offset
		add eax,KERNEL_BIN_BASE_ADDR						; 加上 kernel.bin 被加载到的物理内存地址，得到该段的物理内存地址
		push eax											; 参数 src
		push dword [ebx + 8]								; Program Header 中偏移 8 字节处是 p_vaddr
															; 参数 dst
		call mem_cpy										; 调用 mem_cpy 完成段复制
		add esp,12											; 清理栈中所压入的 3 个参数

	.PTNULL:
		add ebx,edx											; EBX 指向下一个 Program Header
		loop .each_segment

	ret


;------------------------------------------------------------ 
; 字节拷贝
;------------------------------------------------------------ 
; 输入: 
; 栈中三个参数(dst, src, size)
mem_cpy:
	cld														; 从低地址到高地址
	push ebp
	push edi
	push esi
	push ecx

	mov ebp,esp												; EBP 指向栈顶，准备获取所传参数
	mov edi,[ebp + 16]										; 获取 dst
	mov esi,[ebp + 20]										; 获取 src
	mov ecx,[ebp + 24]										; 获取 size
	rep movsb												; 将 src 逐字节拷贝到 dst

	pop ecx
	pop esi
	pop edi
	pop ebp

	ret


;------------------------------------------------------------ 
; 创建页目录以及页表
;------------------------------------------------------------ 
setup_page:
		mov ecx,4096										; 标准页是 4KB，即 4096B
		mov esi,0
	.clear_page_dir:
		mov byte [PAGE_DIR_TABLE_POS + esi],0				; 将页目录所占空间逐字节清零
		inc esi
		loop .clear_page_dir

	.create_pde:
		mov eax,PAGE_DIR_TABLE_POS							; EAX 指向页目录首地址
		add eax,0x1000										; 0x1000 = 4K，这里加上 4KB 表示指向第一个页表的位置
		mov ebx,eax											; 将第一个页表的地址放置于 EBX 基址寄存器中，为创建 PTE 做准备
		or eax,PG_US_U | PG_RW_W | PG_P						; 设置第一个页表的属性：US(1)，RW(1)，P(1)
		mov [PAGE_DIR_TABLE_POS + 0x0],eax					; 把第一个页表地址写入到页目录项 0 中
		mov [PAGE_DIR_TABLE_POS + 0xc00],eax				; 把第一个页表地址写入到页目录项 768(即 0xc00) 中，0xc00 以上的目录项用于内核空间
															; 也就是页表的 0xc0000000 ～ 0xffffffff 共计 1G 属于内核，0x0 ～ 0xbfffffff 共计 3G 属于用户进程
		sub eax,0x1000										; EAX 指向页目录
		mov [PAGE_DIR_TABLE_POS + 4092],eax					; 使最后一个目录项指向页目录表自己的地址，目的是为了将来能够动态操作页表

		mov ecx,256											; 4KB * 256 = 1MB，这里要遍历 1MB 低端内存
		mov esi,0
		mov edx,PG_US_U | PG_RW_W | PG_P					; 设置 PTE 页表的属性：US(1)，RW(1)，P(1)。高位(地址位)先置了 0，表示第 0 页
	.create_pte:
		mov [ebx + esi * 4],edx								; 此时 EBX 已指向第一个页表的地址
		add edx,4096										; EDX 指向下一个页表地址
		inc esi
		loop .create_pte

		mov eax,PAGE_DIR_TABLE_POS							; EAX 指向页目录首地址
		add eax,0x2000										; 0x1000 = 8K，这里加上 8KB 表示指向第二个页表的位置
		or eax,PG_US_U | PG_RW_W | PG_P						; 设置第二个页表的属性：US(1)，RW(1)，P(1)
		mov ebx,PAGE_DIR_TABLE_POS							; EBX 指向页目录首地址
		mov ecx,254											; 遍历范围为第 769 ～ 1022 共 254 个目录项（第 1023 项被用来指向页目录自身了）
															; 第 255 个 PDE 已经指向了页目录表本身
		mov esi,769
	.create_kernel_pde:
		mov [ebx + esi * 4],eax								; 将第 2+ 个页表地址放置于页目录的第 769+ 项
		inc esi												; ESI 指向下一个页目录项
		add eax,0x1000										; EAX 指向下一个物理页
		loop .create_kernel_pde

	ret

;------------------------------------------------------------ 
; 读取磁盘
;------------------------------------------------------------ 
; 输入: 
; EAX = LBA 扇区号
; EBX = 目标内存起始地址
; ECX = 读入的扇区数（主要使用的是 CX）
rd_disk_m_32:
	mov esi,eax												; 备份 EAX
	mov di,cx												; 备份 CX

	;读写硬盘: 
    
    ;第 1 步: 设置要读取的扇区数 
    mov dx,0x1f2            								; 端口 0x1f2（扇区数寄存器）
    mov al,cl               								; 读取的扇区数
    out dx,al               								; 将 al (1) 写入到端口 dx (0x1f2)

    mov eax,esi             								; 恢复 eax 为扇区 lba 地址

    ;第 2 步: 将 LBA 地址存入 0x1f3 ～ 0x1f6 
    
    ; LBA 7～0 位写入端口 0x1f3 
    mov dx,0x1f3 
    out dx,al               								; 将 al 写入到端口 dx (0x1f3)

    ; LBA 15～8 位写入端口 0x1f4 
    mov cl,8 
    shr eax,cl              								; 右移 8 位
    mov dx,0x1f4 
    out dx,al               								; 将 al 写入到端口 dx (0x1f4)

    ; LBA 23～16 位写入端口 0x1f5 
    shr eax,cl              								; 右移 8 位
    mov dx,0x1f5 
    out dx,al               								; 将 al 写入到端口 dx (0x1f5)

    ; LBA 27～24 位写入端口 0x1f6
    shr eax,cl              								; 右移 8 位
    and al,0x0f             								; device 寄存器的低 4 位表示 LBA 27～24 位 
    or al,0xe0              								; 设置第 4 位为 0，表示 lba 主盘（1 为从盘）
                            								; 设置第 5 位固定为 1，表示 MBS 位
                            								; 设置第 6 位为 1，表示启动 LBA 模式（0 为 CHS 模式）
                            								; 设置第 7 位固定为 1，表示 MBS 位
    mov dx,0x1f6 
    out dx,al

    ; 第 3 步: 向 0x1f7 端口写入读命令
    mov dx,0x1f7 
    mov al,0x20             								; 0x20: 读扇区
                            								; 0x30: 写扇区
                            								; 0xEC: 硬盘识别
    out dx,al

	; 至此,硬盘控制器便从指定的 LBA 地址(EAX)处,读出连续的 CX 个扇区

    ; 第 4 步: 检测硬盘状态 
    .not_ready: 
        nop 
        in al,dx                							; 同一端口(0x1f7)，写时表示写入命令字，读时表示读入硬盘状态 
        and al,0x88             							; 第 3 位为 1 表示硬盘控制器已准备好数据传输（数据就绪）
                                							; 第 7 位为 1 表示硬盘忙 
        cmp al,0x08             							; 是否数据就绪且不忙
        jnz .not_ready          							; 若未准备好,继续等 

        ; 第 5 步: 从 0x1f0 端口读数据 
        mov ax,di               							; di 是 cx 参数的备份，表示要数据的扇区数量
        mov dx,256              							; dx = 256，一个扇区有 512 字节,每次读入一个字，所以需要读取 256 次
        mul dx                  							; eax = ax * dx
        mov cx,ax               							; 设置最终需要读取的次数
        mov dx,0x1f0            							; 设置读取数据的端口
    
    .go_on_read: 
        in ax,dx                							; 从端口(0x1f0)读取 16 位数据到 ax
        mov [ebx],ax             							; 将数据写入目标地址
        add ebx,2											; 使用 EBX 代替 BX 指向缓冲区，以防止偏移地址溢出
        loop .go_on_read

	ret
