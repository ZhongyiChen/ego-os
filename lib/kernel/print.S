; 选择子的第 2 位：TI 位，TI 为 0 表示 GDT 索引描述符
TI_GDT                  equ 0_00b

; 指令请求特权级 0（最高）
RPL0                    equ   00b

; GDT 的 VIDEO_DESC 选择子
SELECTOR_VIDEO 		    equ (0x0003<<3) + TI_GDT + RPL0


[bits 32]

section .text
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