#!/bin/bash

./gen-loader.sh

# 编译
gcc -c -o ./dist/main.o ./kernel/main.c

# 连接。生成 kernel.bin
ld ./dist/main.o -Ttext 0xc0001500 -e main -o ./dist/kernel.bin

# 把 kernel.bin 刻录到 hd60M.img 上
dd if=./dist/kernel.bin of=./dist/hd60M.img bs=512 count=200 seek=9 conv=notrunc
