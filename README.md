# ego OS

## FLOPPY IMAGE

* Creating **hd60M.img** if not exist

```sh
dd if=/dev/zero of=./dist/hd60M.img bs=1M count=60
```


## MBR

* Preparing sh script

```sh
chmod 755 gen-mbr.sh
```

* Excuting

```sh
./gen-mbr.sh
```


## LOADER

* Preparing sh scripts

```sh
chmod 755 gen-mbr.sh
chmod 755 gen-loader.sh
```

* Excuting

```sh
./gen-loader.sh
```


## RUNNING

* Mounting **hd60M.img** to the floppy driver of the machine

Check your floppy controller.
