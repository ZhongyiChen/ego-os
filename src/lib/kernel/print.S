; 选择子的第 2 位：TI 位，TI 为 0 表示 GDT 索引描述符
TI_GDT                  equ 0_00b

; 指令请求特权级 0（最高）
RPL0                    equ   00b

; GDT 的 VIDEO_DESC 选择子
SELECTOR_VIDEO 		    equ (0x0003<<3) + TI_GDT + RPL0


[bits 32]
section .text

;------------------------------------------------------------ 
; 打印一个无符号整数到屏幕
;
; 注意！！！这里的指令在内存中位于 0x16b0
;------------------------------------------------------------ 
; 输入: 
; 栈中一个 32 位无符号整数(num)
global put_int
put_int:
	push esi

	mov esi,[esp + 8]										; 获取参数整数
	
	.exchange_and_print:
		push esi
		call bin_to_bcd										; 返回 EDX:EAX
		pop esi

		cmp edx,0
		jz .print_low_part									; 如果高位全是 0，则跳过

	.print_high_part:
		push edx
		call put_bcd										; 打印高 16 位 BCD
		pop edx
		
	.print_low_part:
		push eax
		call put_bcd										; 打印低 16 位 BCD
		pop eax

	pop esi
	ret


;------------------------------------------------------------ 
; 打印一个 BCD/HEX 整数到屏幕
;------------------------------------------------------------ 
; 输入: 
; 栈中一个 8 位 BCD/HEX (32 bits)
global put_hex
global put_bcd
put_hex:
put_bcd:
	push eax
	push ecx
	push ebx
	push esi
	push edi

	mov esi,[esp + 24]									; 获取参数
	mov edi,0x03										; 表示至少打印一个 BCD/HEX 字符(4 bits)，这里指向第 3 个字符

	bsr ebx,esi
	cmovz ebx,edi										; 数值 0 则只打印单个 0 即可
	inc ebx												; 由于序号从 0 开始，因此这里补偿 1

	mov eax,ebx
	and eax,0x03
	jz .is_fours										; 如果 EAX 此时为 0，说明 EBX 是 4 的倍数

	xor ebx,eax											; 非 4 的倍数，则向上调整为 4 的倍数
	add ebx,0x04

	.is_fours:
		mov ecx,32
		sub ecx,ebx											; ECX (CL)此时等于 ESI 需要提前左移的位数
		shl esi,cl

		mov ecx,ebx
		shr ecx,2											; EBX / 4 = 需要循环的次数

		mov ebx,'A'
		sub ebx,10											; EBX = 'A' - 10，为接下来的数字转字符做准备

		cmp ecx,0
		jnz .extract_bcd
		mov ecx,1											; ECX 不能为 0，至少要大于等于 1

	.extract_bcd:
		xor eax,eax
		shld eax,esi,4
		shl esi,4
		mov edi,'0'
		cmp eax,9
		cmova edi,ebx										; 如果 EAX > 9，EDI = 'A' - 10；否则，EDI = '0'
		add eax,edi											; EAX + EDI = '0' ~ 'F'
		push eax
		call put_char
		pop eax
		loop .extract_bcd

	.put_bcd_end:

	pop edi
	pop esi
	pop ebx
	pop ecx
	pop eax
	ret

;------------------------------------------------------------ 
; 打印一个字符串到屏幕
;------------------------------------------------------------ 
; 输入: 
; 栈中一个参数(str)
global put_str
put_str:
	push ebx
	push ecx

	mov ebx,[esp + 12]										; 获取参数字符串地址

	.go_on:
		xor ecx,ecx											; 清零，准备使用 CL 作为字符载体
		mov cl,[ebx]
		cmp cl,0											; 0x0 字符表示字符串结尾
		jz .str_end
		push ecx											; 为 put_char 函数提供参数
		call put_char
		pop ecx												; 目的是为了实现 `add esp,4`
		inc ebx												; EBX 指向下一个字符
		jmp .go_on

	.str_end:

	pop ecx
	pop ebx
	ret

;------------------------------------------------------------ 
; 打印一个字符到屏幕
;------------------------------------------------------------ 
; 输入: 
; 栈中一个参数(char)
global put_char
put_char:
	pushad										            ; 依次压入 `EAX`、`ECX`、`EDX`、`EBX`、`ESP`、`EBP`、`ESI`、`EDI`。仅 32 位模式可用
    mov ax,SELECTOR_VIDEO                                   ; 准备加载视频段选择子
    mov gs,ax                                               ; GS 指向视频段

    ;; 先获取当前光标的位置 (当前位于文本模式 80*25) ;;
	;; 光标位置是一个 16 位的值，表示从屏幕左上角 (0, 0) 开始的(字符)偏移量 ;;
	;; VGA 采用 索引-数据对 的模式，因此下面的操作均是先写入一个地址寄存器，然后接着写入一个数据寄存器 ;;
    
	mov dx,0x03d4
	mov al,0x0e
	out dx,al												; 把 0x0E (光标高字节寄存器) 写入到 0x3D4 (CRTC 地址寄存器) 中，准备获取当前光标位置的高 8 位
	mov dx,0x03d5
	in al,dx												; 读取 0x3D5 (CRTC 数据寄存器)，获得当前光标位置的高 8 位
	mov ah,al

	mov dx,0x03d4
	mov al,0x0f
	out dx,al												; 把 0x0F (光标低字节寄存器) 写入到 0x3D4 (CRTC 地址寄存器) 中，准备获取当前光标位置的低 8 位
	mov dx,0x03d5
	in al,dx												; 读取 0x3D5 (CRTC 数据寄存器)，获得当前光标位置的低 8 位。到此，AX 就是完整的 16 位光标位置

	mov bx,ax												; 将 16 位大小的光标位置放置于 BX 中

	mov ecx,[esp + 36]										; 在栈中获取待打印的字符 (第一个参数)，其中 CX 的低 8 位存储 ASCII 码，高 8 位存储显示属性
															; PUSHAD 压入 4*8 = 32 字节，主调函数进来前亦压入返回地址共 4 字节，因此 ESP 须加上 36
	cmp cl,0xd												; 判断字符是否为回车符 CR
	jz .is_carriage_return
	
	cmp cl,0xa												; 判断字符是否为换行符 LF
	jz .is_line_feed

	cmp cl,0x8												; 判断字符是否为退格符 BS
	jz .is_backspace

	jmp .put_other											; 其余字符一律按正常文字字符处理

	.is_backspace:
		dec bx												; 光标值 -1
		shl bx,1											; 光标值 *2，得到退格后的偏移字节数
		mov byte [gs:bx],0x20								; 将光标位置的字符变成空格符 0x20 (SPACE)
		inc bx												; BX + 1 指向当前字符的属性字节
		mov byte [gs:bx],0x07								; 0x07 表示黑底白字
		shr bx,1											; BX / 2 = 光标值，即 BX 恢复光标值
		jmp .set_cursor

	.put_other:
		shl bx,1											; 光标值 *2，得到当前光标的偏移字节数
		mov [gs:bx],cl										; 把 ASCII 字符写入低字节
		inc bx
		mov byte [gs:bx],0x07								; 把显示属性写入高字节
		shr bx,1											; BX / 2 = 光标值，即 BX 恢复光标值
		inc bx												; 光标指向下一个字符位置
		cmp bx,2000											; 检测光标是否位于屏幕外
		jl .set_cursor										; 如果光标仍然位于屏幕内，则设置新的光标
															; 否则，进行换行处理
	
	.is_line_feed:											; 换行符 LF(\n)
	.is_carriage_return:									; 回车符 CR(\r)，将光标移至行首。这里把 \n 与 \r 一视同仁，都执行换行与回车
		xor dx,dx											; 被除数的高 16 位，清零
		mov ax,bx											; 被除数的低 16 位
		mov si,80											; 每行 80 个字符
		div si												; (DX:AX) / SI，商为 AX，余为 DX
		sub bx,dx											; BX 指向了当前行行首。这就是对 CR 的处理
		
		add bx,80											; BX 指向了下一行的行首。这就是对 LF 的处理
		cmp bx,2000											; 检测光标是否位于屏幕外
		jl .set_cursor										; 如果光标仍然位于屏幕内，则设置新的光标

	.roll_screen:
		cld
		mov ecx,960											; 需要搬运的字符数 = 2000 - 80 = 1920 个，共 1920 * 2 = 3840 字节，需要搬运的次数 = 3840 / 4 = 960 次
		mov esi,0xc00b80a0									; 第 1 行行首
		mov edi,0xc00b8000									; 第 0 行行首
		rep movsd

		mov ebx,3840										; 最后一行在页面的偏移字节数
		mov ecx,80											; 一行有 80 个字符

	.cls:
		mov word [gs:ebx],0x0720							; 填充黑底白字的空格符
		add ebx,2
		loop .cls
		mov bx,1920											; 将光标重置为 1920，即最后一行的首字符

	.set_cursor:
		mov dx,0x03d4
		mov al,0x0e
		out dx,al											; 把 0x0E (光标高字节寄存器) 写入到 0x3D4 (CRTC 地址寄存器) 中，准备设置当前光标位置的高 8 位
		mov dx,0x03d5
		mov al,bh
		out dx,al											; 把当前光标位置的高 8 位写入 0x3D5 (CRTC 数据寄存器)
		
		mov dx,0x03d4
		mov al,0x0f
		out dx,al											; 把 0x0F (光标低字节寄存器) 写入到 0x3D4 (CRTC 地址寄存器) 中，准备设置当前光标位置的低 8 位
		mov dx,0x03d5
		mov al,bl
		out dx,al											; 把当前光标位置的低 8 位写入 0x3D5 (CRTC 数据寄存器)

    popad                                                   ; 对应 PUSHAD 指令。它们结对出现
    ret

;------------------------------------------------------------ 
; 32 位 binary 无符号整数转换成 BCD
;
; 注意！！！这里的指令在内存中位于 0x17fa
;------------------------------------------------------------ 
; 输入: 
; 栈中一个 32 位无符号整数
;
; 输出: 
; EDX:EAX
bin_to_bcd:
	push ecx
	push ebx
	push esi

	xor edx,edx												; 清零
	xor eax,eax
	mov esi,[esp + 16]
	bsr ebx,esi												; 找到最高位的 1 在寄存器的下标，作为循环次数 (先暂存于 EBX，其实只占用到了 BL)
	jz .exchange_end
	mov ecx,31
	sub ecx,ebx												; CL = (32 - 1) - BL
	sal esi,cl
	mov ecx,ebx												; 把循环次数赋值给 ECX，准备开始循环
	inc ecx													; 由于 EBX 存储的是最高位 1 的下标，因此这里加 1 以修正循环次数

	.exchanging_bcd:										; EDX:EAX:ESI 作为一个整体将执行多次左移操作
		push esi
		call reach_5_add_3
		pop esi
		sal esi,1											; ESI 的最高位进入 CF
		rcl eax,1											; EAX:CF 作为一个整体执行左移操作
		rcl edx,1											; EDX:CF 作为一个整体执行左移操作
															; 这里也可以使用 `shld edx,eax,1` +  `shld eax,esi,1` + `shl esi,1` 实现同样的功能逻辑
		loop .exchanging_bcd

	.exchange_end:

	pop esi
	pop ecx
	pop ebx
	ret

;------------------------------------------------------------ 
; 对 EDX:EAX 每 4 位执行满 5 加 3
;
; 注意！！！这里的指令在内存中位于 0x1826
;------------------------------------------------------------ 
; 输入: 
; EDX - 高 32 位
; EAX - 高 32 位
;
; 输出: 
; EDX - 高 32 位
; EAX - 高 32 位
reach_5_add_3:
	push ebx
	push ebp
	push esi
	push edi

	mov ebp,0x0000000F
	
	.compare_and_add:
		mov esi,eax
		and esi,ebp												; 取出原始值(某 4 位)放入 ESI 与 EDI
		mov edi,esi
		mov ebx,0x33333333
		and ebx,ebp
		add edi,ebx												; EDI (某 4 位) = ESI(某 4 位) + 3
		mov ebx,0x55555555
		and ebx,ebp
		cmp esi,ebx												; ESI (某 4 位)与 5 进行比较
		cmovb edi,esi											; 如果 ESI (某 4 位) < 5，则 EDI = ESI；否则 EDI = EDI
		xor eax,esi												; EAX 的对应当前 4 位清 0
		or eax,edi												; EAX 加上已处理好某 4 位
		
		mov esi,edx
		and esi,ebp												; 取出原始值(某 4 位)放入 ESI 与 EDI
		mov edi,esi
		mov ebx,0x33333333
		and ebx,ebp
		add edi,ebx												; EDI (某 4 位) = ESI(某 4 位) + 3
		mov ebx,0x55555555
		and ebx,ebp
		cmp esi,ebx												; ESI (某 4 位)与 5 进行比较
		cmovb edi,esi											; 如果 ESI (某 4 位) < 5，则 EDI = ESI；否则 EDI = EDI
		xor edx,esi												; EDX 的对应当前 4 位清 0
		or edx,edi												; EDX 加上已处理好某 4 位

		shl ebp,4
		cmp ebp,0
		jnz .compare_and_add

	pop edi
	pop esi
	pop ebp
	pop ebx
	ret
