#!/bin/bash

./gen-mbr.sh

# 生成 loader.bin
nasm -I include/ -o ./dist/loader.bin loader.S

# 把 loader.bin 刻录到 hd60M.img 上
dd if=./dist/loader.bin of=./dist/hd60M.img bs=512 count=4 seek=2 conv=notrunc
