DIST_DIR := ./dist
OBJ_DIR := ./dist/obj
SRC_DIR := ./src

AS := nasm
CC := gcc
LD := ld

ENTRY_POINT := 0xc0001500

AS_LIB := -I $(SRC_DIR)/include/
C_LIB := -I $(SRC_DIR)/lib/ -I $(SRC_DIR)/lib/kernel/ -I $(SRC_DIR)/kernel/ -I $(SRC_DIR)/device/
ASFLAGS := -f elf
CFLAGS := -m32 -ffreestanding -nostdlib -fno-builtin -Wstrict-prototypes -Wmissing-prototypes $(C_LIB) -c
LDFLAGS := -melf_i386 -Ttext $(ENTRY_POINT) -e main

IMG_FILE := hd60M.img
# C_FILES := $(SRC_DIR)/**/*.c
# O_FILES := $(C_FILES:$(SRC_DIR)/%.c=$(DIST_DIR)/%.o)
O_FILES := $(OBJ_DIR)/main.o \
	$(OBJ_DIR)/init.o \
	$(OBJ_DIR)/interrupt.o \
	$(OBJ_DIR)/timer.o \
	$(OBJ_DIR)/kernel.o \
	$(OBJ_DIR)/print.o \
	$(OBJ_DIR)/debug.o \
	$(OBJ_DIR)/memory.o \
	$(OBJ_DIR)/bitmap.o \
	$(OBJ_DIR)/string.o


$(DIST_DIR)/mbr.bin: $(SRC_DIR)/boot/mbr.S
	$(AS) $(AS_LIB) $< -o $@


$(DIST_DIR)/loader.bin: $(SRC_DIR)/boot/loader.S
	$(AS) $(AS_LIB) $< -o $@


$(OBJ_DIR)/main.o: $(SRC_DIR)/kernel/main.c \
		$(SRC_DIR)/lib/kernel/print.h \
		$(SRC_DIR)/kernel/init.h \
		$(SRC_DIR)/kernel/debug.h \
        $(SRC_DIR)/lib/stdint.h
	$(CC) $(CFLAGS) $< -o $@

$(OBJ_DIR)/init.o: $(SRC_DIR)/kernel/init.c \
		$(SRC_DIR)/kernel/init.h \
		$(SRC_DIR)/lib/kernel/print.h \
		$(SRC_DIR)/kernel/interrupt.h \
        $(SRC_DIR)/device/timer.h \
        $(SRC_DIR)/lib/stdint.h
	$(CC) $(CFLAGS) $< -o $@

$(OBJ_DIR)/interrupt.o: $(SRC_DIR)/kernel/interrupt.c \
		$(SRC_DIR)/kernel/interrupt.h \
		$(SRC_DIR)/lib/kernel/global.h \
		$(SRC_DIR)/lib/kernel/io.h \
		$(SRC_DIR)/lib/kernel/print.h \
        $(SRC_DIR)/lib/stdint.h
	$(CC) $(CFLAGS) $< -o $@

$(OBJ_DIR)/timer.o: $(SRC_DIR)/device/timer.c \
		$(SRC_DIR)/device/timer.h \
		$(SRC_DIR)/lib/kernel/io.h \
		$(SRC_DIR)/lib/kernel/print.h \
        $(SRC_DIR)/lib/stdint.h
	$(CC) $(CFLAGS) $< -o $@

$(OBJ_DIR)/debug.o: $(SRC_DIR)/kernel/debug.c \
		$(SRC_DIR)/kernel/debug.h \
		$(SRC_DIR)/lib/kernel/print.h \
		$(SRC_DIR)/kernel/interrupt.h \
        $(SRC_DIR)/lib/stdint.h
	$(CC) $(CFLAGS) $< -o $@

$(OBJ_DIR)/string.o: $(SRC_DIR)/lib/string.c \
		$(SRC_DIR)/lib/string.h \
		$(SRC_DIR)/lib/kernel/global.h \
		$(SRC_DIR)/kernel/debug.h \
        $(SRC_DIR)/lib/stdint.h
	$(CC) $(CFLAGS) $< -o $@

$(OBJ_DIR)/bitmap.o: $(SRC_DIR)/lib/kernel/bitmap.c \
		$(SRC_DIR)/lib/kernel/bitmap.h \
		$(SRC_DIR)/lib/kernel/global.h \
		$(SRC_DIR)/lib/string.h \
		$(SRC_DIR)/lib/kernel/print.h \
		$(SRC_DIR)/kernel/interrupt.h \
		$(SRC_DIR)/kernel/debug.h \
        $(SRC_DIR)/lib/stdint.h
	$(CC) $(CFLAGS) $< -o $@

$(OBJ_DIR)/memory.o: $(SRC_DIR)/kernel/memory.c \
		$(SRC_DIR)/kernel/memory.h \
		$(SRC_DIR)/lib/kernel/bitmap.h \
		$(SRC_DIR)/lib/kernel/print.h \
        $(SRC_DIR)/lib/stdint.h
	$(CC) $(CFLAGS) $< -o $@

$(OBJ_DIR)/kernel.o: $(SRC_DIR)/kernel/kernel.S
	$(AS) $(ASFLAGS) $< -o $@

$(OBJ_DIR)/print.o: $(SRC_DIR)/lib/kernel/print.S
	$(AS) $(ASFLAGS) $< -o $@


$(DIST_DIR)/kernel.bin: $(O_FILES)
	$(LD) $(LDFLAGS) $^ -o $@


# 声明 clean 等为伪目标名，作用是确保该目标下的命令永远被执行，而不考虑是否产生真实的目标文件
.PHONY: mk_dir mk_img hd clean all

mk_dir:
	if [ ! -d $(DIST_DIR) ];then mkdir $(DIST_DIR) ;fi
	if [ ! -d $(OBJ_DIR) ];then mkdir $(OBJ_DIR) ;fi

mk_img:
	if [ ! -e $(DIST_DIR)/$(IMG_FILE) ];then dd if=/dev/zero of=$(DIST_DIR)/$(IMG_FILE) bs=1M count=60 ;fi

build: $(DIST_DIR)/kernel.bin $(DIST_DIR)/mbr.bin $(DIST_DIR)/loader.bin

hd:
	dd if=$(DIST_DIR)/mbr.bin of=$(DIST_DIR)/hd60M.img bs=512 count=1 conv=notrunc
	dd if=$(DIST_DIR)/loader.bin of=$(DIST_DIR)/hd60M.img bs=512 count=4 seek=2 conv=notrunc
	dd if=$(DIST_DIR)/kernel.bin of=$(DIST_DIR)/hd60M.img bs=512 count=200 seek=9 conv=notrunc

clean:
	cd $(DIST_DIR) && rm -rf ./*

all: mk_dir mk_img build hd
