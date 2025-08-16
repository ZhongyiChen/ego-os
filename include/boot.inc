
; --------------------------------------------------
;                      MBR
; --------------------------------------------------
MBR_BASE_ADDR       equ 0x7c00



; --------------------------------------------------
;                    LOADER
; --------------------------------------------------
LOADER_BASE_ADDR    equ 0x900
LOADER_START_SECTOR equ 0x2


; --------------------------------------------------
;                      GDT
; --------------------------------------------------

; 高 32 位的第 23 位：G 位，表示 4K 粒度。实际界限 = 描述符界限 × 4096 + 4095
DESC_G_4K           equ 1_0000000_00000000_00000000b

; 高 32 位的第 22 位：D/B 位(代码段是 D)，表示 32 位操作数
DESC_D_32           equ  1_000000_00000000_00000000b

; 高 32 位的第 21 位：L 位，表示非 64 位系统
DESC_L              equ   0_00000_00000000_00000000b

; 高 32 位的第 20 位：AVL 位，保留给操作系统使用
DESC_AVL            equ    0_0000_00000000_00000000b

; 高 32 位的第 16 ~ 19 位：段界限的第 2 部分
DESC_LIMIT_CODE2    equ      1111_00000000_00000000b
DESC_LIMIT_DATA2    equ DESC_LIMIT_CODE2
DESC_LIMIT_VIDEO2   equ      0000_00000000_00000000b

; 高 32 位的第 15 位：P 位，表示段存在内存中
DESC_P              equ          1_0000000_00000000b

; 高 32 位的第 13 ~ 14 位：DPL 位，数字越小，特权级越大，这里表示最高特权级
DESC_DPL_0          equ           00_00000_00000000b
DESC_DPL_1          equ           01_00000_00000000b
DESC_DPL_2          equ           10_00000_00000000b
DESC_DPL_3          equ           11_00000_00000000b

; 高 32 位的第 12 位：S 位，此值为 1，表示它是个普通的内存段，不是系统段
DESC_S_CODE         equ             1_0000_00000000b
DESC_S_DATA         equ DESC_S_CODE

; 高 32 位的第 12 位：S 位，此值为 0，表示它是个系统段(各种称为“门”的结构)
DESC_S_sys          equ             0_0000_00000000b

; 高 32 位的第 8 ~ 11 位：TYPE 位，x=1, c=0, r=0, a=0
;                        代码段是可执行的，非一致性，不可读，已访问位 a 清 0
DESC_TYPE_CODE      equ               1000_00000000b

; 高 32 位的第 8 ~ 11 位：TYPE 位，x=0, e=0, w=1, a=0
;                        数据段是不可执行的，向上扩展的，可写，已访问位 a 清 0
DESC_TYPE_DATA      equ               0010_00000000b

; 代码段的高 4 字节
DESC_CODE_HIGH4     equ (0x00 << 24) + DESC_G_4K + DESC_D_32 + \
                        DESC_L + DESC_AVL + DESC_LIMIT_CODE2 + \
                        DESC_P + DESC_DPL_0 + DESC_S_CODE + \
                        DESC_TYPE_CODE + 0x00

; 数据段的高 4 字节
DESC_DATA_HIGH4     equ (0x00 << 24) + DESC_G_4K + DESC_D_32 + \
                        DESC_L + DESC_AVL + DESC_LIMIT_DATA2 + \
                        DESC_P + DESC_DPL_0 + DESC_S_DATA + \
                        DESC_TYPE_DATA + 0x00

; 代码段的高 4 字节
DESC_VIDEO_HIGH4    equ (0x00 << 24) + DESC_G_4K + DESC_D_32 + \
                        DESC_L + DESC_AVL + DESC_LIMIT_VIDEO2 + \
                        DESC_P + DESC_DPL_0 + DESC_S_DATA + \
                        DESC_TYPE_DATA + 0x0B


; --------------------------------------------------
;                     SELECTOR
; --------------------------------------------------

; 选择子的第 0 ～ 1 位：RPL 位，数字越小，所请求特权级越大，这里 0 表示最高特权级
RPL0                equ   00b
RPL1                equ   01b
RPL2                equ   10b
RPL3                equ   11b

; 选择子的第 2 位：TI 位，TI 为 0 表示 GDT 索引描述符
;						TI 为 1 表示 LDT 索引描述符
TI_GDT              equ 0_00b
TI_LDT              equ 1_00b


; --------------------------------------------------
;                      PAGE
; --------------------------------------------------

; 二级页目录表，放在内存中 1MB 起始位置，所有页表连续存放
PAGE_DIR_TABLE_POS  equ 0x100000

PG_P                equ     1b
PG_RW_R             equ   0_0b
PG_RW_W             equ   1_0b
PG_US_S             equ 0_0_0b
PG_US_U             equ 1_0_0b
