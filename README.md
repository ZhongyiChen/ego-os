# ego OS

## MBR

* Compiling **mbr.S** into **mrb.bin**

```sh
nasm -o ./dist/mbr.bin mbr.S
```

* Creating **hd60M.img** if not exist

```sh
dd if=/dev/zero of=./dist/hd60M.img bs=1M count=60
```

* Writing **mbr.bin** on **hd60M.img**

```sh
dd if=./dist/mbr.bin of=./dist/hd60M.img bs=512 count=1 conv=notrunc
```

* Mounting **hd60M.img** to the floppy driver of the machine

Check your floppy controller.
