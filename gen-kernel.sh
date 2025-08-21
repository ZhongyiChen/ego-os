#!/bin/bash

if [ ! -d "dist" ]; then
    mkdir dist
fi

if [ ! -d "dist/kernel" ]; then
    mkdir dist/kernel
fi

./gen-loader.sh

# 编译 print
nasm -f elf -o dist/kernel/print.o lib/kernel/print.S

# 编译 main
# -ffreestanding 表示代码在独立环境中运行，不依赖标准库
# -nostdlib 不链接标准库
# -fno-builtin 禁用内建函数
gcc -m32 -ffreestanding -nostdlib -fno-builtin -I lib -I lib/kernel/ -c -o dist/kernel/main.o kernel/main.c

# 连接。生成 kernel.bin
ld -melf_i386 -Ttext 0xc0001500 -e main -o dist/kernel.bin dist/kernel/main.o dist/kernel/print.o

# 把 kernel.bin 刻录到 hd60M.img 上
dd if=./dist/kernel.bin of=./dist/hd60M.img bs=512 count=200 seek=9 conv=notrunc
