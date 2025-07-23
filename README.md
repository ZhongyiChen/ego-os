# ego OS

## FLOPPY IMAGE

* Creating **hd60M.img** if not exist

```sh
dd if=/dev/zero of=./dist/hd60M.img bs=1M count=60
```


## MBR

* Compiling **mbr.S** into **mbr.bin**

```sh
nasm -I include/ -o ./dist/mbr.bin mbr.S
```

* Writing **mbr.bin** on **hd60M.img**

```sh
dd if=./dist/mbr.bin of=./dist/hd60M.img bs=512 count=1 conv=notrunc
```


## LOADER

* Compiling **loader.S** into **loader.bin**

```sh
nasm -I include/ -o ./dist/loader.bin loader.S
```

* Writing **loader.bin** on **hd60M.img**

```sh
dd if=./dist/loader.bin of=./dist/hd60M.img bs=512 count=1 seek=2 conv=notrunc
```


## RUNNING

* Mounting **hd60M.img** to the floppy driver of the machine

Check your floppy controller.
