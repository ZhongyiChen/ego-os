#!/bin/bash

if [ ! -d "dist" ]; then
    mkdir dist
fi

if [ ! -e "./dist/hd60M.img" ]; then
    dd if=/dev/zero of=./dist/hd60M.img bs=1M count=60
fi

# Compiling mbr.S into mbr.bin
nasm -I include/ -o ./dist/mbr.bin ./boot/mbr.S

# Writing mbr.bin on hd60M.img
dd if=./dist/mbr.bin of=./dist/hd60M.img bs=512 count=1 conv=notrunc
