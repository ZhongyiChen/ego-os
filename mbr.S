; 主引导程序 
;-----------------------------------------------------------
%include "include/boot.inc"
SECTION MBR vstart=MBR_BASE_ADDR
    mov ax,cs               ; CS=0x0000（BIOS 跳转到 MBR 时，CS:IP=0x0000:0x7c00）
    mov ds,ax               ; DS=0x0000（数据段）
    mov es,ax               ; ES=0x0000（附加段）
    mov ss,ax               ; SS=0x0000（栈段）
    mov fs,ax               ; FS=0x0000（未使用）
    mov sp,MBR_BASE_ADDR    ; SP=0x7c00（栈指针，栈向下增长）
    mov ax,0xb800           ; 文本模式显存段地址（0xb8000）
    mov gs,ax               ; GS=0xb800（用于直接操作显存）

; 清屏（利用 0x06 号功能,上卷全部行,则可清屏）
;-----------------------------------------------------------
; INT 0x10   功能号:0x06    功能描述:上卷窗口 
;-----------------------------------------------------------
; 输入: 
; AH = 功能号 0x06 
; AL = 上卷的行数(0 表示全部行)
; BH = 上卷行属性(白色前景黑色背景)
; (CL,CH) = 窗口左上角的(X,Y)位置 
; (DL,DH) = 窗口右下角的(X,Y)位置 
; 无返回值: 
    mov     ax,0x600 
    mov     bx,0x700 
    mov     cx,0            ; 左上角: (0, 0) 
    mov     dx,0x184f       ; 右下角: (80,25) 
                            ; VGA 文本模式中,一行只能容纳 80 个字符,共 25 行  
                            ; 下标从 0 开始,所以 0x18=24,0x4f=79 
    int     0x10            ; 触发 0x10 号中断

    ; 输出背景色绿色，前景色红色，并且跳动的字符串"1 MBR"
    mov byte [gs:0x00],'1' 
    mov byte [gs:0x01],0xA4         ; A 表示绿色背景闪烁，4表示前景色为红色 

    mov byte [gs:0x02],' ' 
    mov byte [gs:0x03],0xA4 

    mov byte [gs:0x04],'M' 
    mov byte [gs:0x05],0xA4 

    mov byte [gs:0x06],'B' 
    mov byte [gs:0x07],0xA4 

    mov byte [gs:0x08],'R' 
    mov byte [gs:0x09],0xA4

    mov eax,LOADER_START_SECTOR     ; 起始扇区 lba 地址
    mov bx,LOADER_BASE_ADDR         ; 写入的地址(0x900)
    mov cx,1                        ; 待读入的扇区数量
    call rd_disk_m_16               ; 调用磁盘读取函数

    jmp LOADER_BASE_ADDR            ; 跳转到 Loader 继续运行

; 功能: 读取硬盘 n 个扇区 （在 16 位模式下读硬盘）
;-----------------------------------------------------------
; eax = LBA 扇区号 
; bx  = 将数据写入的内存地址 
; cx  = 读入的扇区数 
;
; 这里的硬盘采用 LBA28 模式，用 28 位比特描述一个扇区的地址
;-----------------------------------------------------------
rd_disk_m_16: 
    mov esi,eax             ; 备份 eax 
    mov di,cx               ; 备份 cx 
    
    ;读写硬盘: 
    
    ;第 1 步: 设置要读取的扇区数 
    mov dx,0x1f2            ; 端口 0x1f2（扇区数寄存器）
    mov al,cl               ; 读取的扇区数
    out dx,al               ; 将 al (1) 写入到端口 dx (0x1f2)

    mov eax,esi             ; 恢复 eax 为扇区 lba 地址

    ;第 2 步: 将 LBA 地址存入 0x1f3 ～ 0x1f6 
    
    ; LBA 7～0 位写入端口 0x1f3 
    mov dx,0x1f3 
    out dx,al               ; 将 al 写入到端口 dx (0x1f3)

    ; LBA 15～8 位写入端口 0x1f4 
    mov cl,8 
    shr eax,cl              ; 右移 8 位
    mov dx,0x1f4 
    out dx,al               ; 将 al 写入到端口 dx (0x1f4)

    ; LBA 23～16 位写入端口 0x1f5 
    shr eax,cl              ; 右移 8 位
    mov dx,0x1f5 
    out dx,al               ; 将 al 写入到端口 dx (0x1f5)

    ; LBA 27～24 位写入端口 0x1f6
    shr eax,cl              ; 右移 8 位
    and al,0x0f             ; device 寄存器的低 4 位表示 LBA 27～24 位 
    or al,0xe0              ; 设置第 4 位为 0，表示 lba 主盘（1 为从盘）
                            ; 设置第 5 位固定为 1，表示 MBS 位
                            ; 设置第 6 位为 1，表示启动 LBA 模式（0 为 CHS 模式）
                            ; 设置第 7 位固定为 1，表示 MBS 位
    mov dx,0x1f6 
    out dx,al 

    ; 第 3 步: 向 0x1f7 端口写入读命令
    mov dx,0x1f7 
    mov al,0x20             ; 0x20: 读扇区
                            ; 0x30: 写扇区
                            ; 0xEC: 硬盘识别
    out dx,al 

    ; 第 4 步: 检测硬盘状态 
    .not_ready: 
        nop 
        in al,dx                ; 同一端口(0x1f7)，写时表示写入命令字，读时表示读入硬盘状态 
        and al,0x88             ; 第 3 位为 1 表示硬盘控制器已准备好数据传输（数据就绪）
                                ; 第 7 位为 1 表示硬盘忙 
        cmp al,0x08             ; 是否数据就绪且不忙
        jnz .not_ready          ; 若未准备好,继续等 

        ; 第 5 步: 从 0x1f0 端口读数据 
        mov ax,di               ; di 是 cx 参数的备份，表示要数据的扇区数量
        mov dx,256              ; dx = 256，一个扇区有 512 字节,每次读入一个字，所以需要读取 256 次
        mul dx                  ; eax = ax * dx
        mov cx,ax               ; 设置最终需要读取的次数
        mov dx,0x1f0            ; 设置读取数据的端口
    
    .go_on_read: 
        in ax,dx                ; 从端口(0x1f0)读取 16 位数据到 ax
        mov [bx],ax             ; 将数据写入目标地址
        add bx,2 
        loop .go_on_read 
    
    ret 

    times 510-($-$$) db 0 
    db 0x55,0xaa
