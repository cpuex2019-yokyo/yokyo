default: xv6dist linuxdist bootloaderdist

update:
	git submodule update --remote

build:
	mkdir -p build

# xv6
###########
build/xv6:
	mkdir -p build/xv6

xv6dist: build/xv6/kernel.coe build/xv6/fs.coe build/xv6/bootloader.coe build/xv6/fs.img.bin
	cd build; zip -r xv6.zip xv6

# stager for xv6
toolchain/bootloader/xv6/build/bootloader: toolchain/bootloader/xv6
	cd toolchain/bootloader/xv6; make

build/xv6/bootloader.elf: toolchain/bootloader/xv6/build/bootloader build/xv6
	cp toolchain/bootloader/xv6/build/bootloader build/xv6/bootloader.elf

build/xv6/bootloader.bin: build/xv6/bootloader.elf
	yokyo_elf2bin build/xv6/bootloader.elf build/xv6/bootloader.bin

build/xv6/bootloader.coe: build/xv6/bootloader.bin build/xv6
	yokyo_bin2coe build/xv6/bootloader.bin > build/xv6/bootloader.coe

# fs
xv6-riscv/fs.img: 
	cd xv6-riscv; make fs.img

build/xv6/fs.bin: xv6-riscv/fs.img build/xv6
	cp xv6-riscv/fs.img build/xv6/fs.bin

build/xv6/fs.coe: build/xv6/fs.bin build/xv6
	yokyo_bin2coe build/xv6/fs.bin > build/xv6/fs.coe

build/xv6/fs.img.bin: build/xv6/fs.bin build/xv6
	yokyo_bin2flash build/xv6/fs.bin build/xv6/fs.img.bin 4096

# kernel
xv6-riscv/kernel/kernel: xv6-riscv
	cd xv6-riscv; make kernel/kernel

build/xv6/kernel.elf: xv6-riscv/kernel/kernel build/xv6
	cp xv6-riscv/kernel/kernel build/xv6/kernel.elf

build/xv6/kernel.bin: build/xv6/kernel.elf
	yokyo_elf2bin build/xv6/kernel.elf build/xv6/kernel.bin

build/xv6/kernel.coe: build/xv6/kernel.bin build/xv6
	yokyo_bin2coe build/xv6/kernel.bin > build/xv6/kernel.coe

# linux
###########
build/linux:
	mkdir -p build/linux

linuxdist: build/linux/kernel.img.bin
	cd build; zip -r linux.zip linux

linux/arch/riscv/boot/Image: linux busybox/initramfs.cpio.gz
	cd linux; make ARCH=riscv CROSS_COMPILE=riscv32-unknown-linux-gnu- vmlinux Image -j 4

opensbi/build/platform/qemu/virt/firmware/fw_payload.elf: linux/arch/riscv/boot/Image
	cd opensbi; make CROSS_COMPILE=riscv32-unknown-elf- PLATFORM=qemu/virt PLATFORM_RISCV_ABI=ilp32 PLATFORM_RISCV_ISA=rv32ima FW_PAYLOAD_PATH=../linux/arch/riscv/boot/Image

linux/.config: conf/linux.config
	cp conf/linux.config linux/.config

configure:
	cp conf/linux.config linux/.config
	cd linux; make ARCH=riscv CROSS_COMPILE=riscv32-unknown-linux-gnu- menuconfig
	cp linux/.config conf/linux.config

build/linux/kernel.elf: opensbi/build/platform/qemu/virt/firmware/fw_payload.elf build/linux
	cp opensbi/build/platform/qemu/virt/firmware/fw_payload.elf build/linux/kernel.elf

build/linux/kernel.bin: build/linux/kernel.elf
	yokyo_elf2bin build/linux/kernel.elf build/linux/kernel.bin

build/linux/kernel.img.bin: build/linux/kernel.bin
	yokyo_bin2flash build/linux/kernel.bin build/linux/kernel.img.bin 512

# tests
run-linux: build/linux/kernel.elf
	sudo qemu-system-riscv32 \
		-nographic \
		-smp 1 \
		-machine virt \
		-append "console=ttyS0" \
		-kernel opensbi/build/platform/qemu/virt/firmware/fw_payload.elf \
		-trace events=trace-events,file=trace.log

run-linux-gdb: build/linux/kernel.elf
	sudo qemu-system-riscv32 \
		-nographic \
		-smp 1 \
		-machine virt \
		-append "console=ttyS0" \
		-kernel opensbi/build/platform/qemu/virt/firmware/fw_payload.elf \
		-trace events=trace-events,file=trace.log \
		-S -gdb tcp::11451

dumpdtb: busybox/initramfs.cpio.gz opensbi/build/platform/qemu/virt/firmware/fw_payload.elf
	sudo qemu-system-riscv32 \
		-nographic \
		-machine virt \
		-machine dumpdtb=board.dtb \
		-append "console=ttyS0" \
		-kernel opensbi/build/platform/qemu/virt/firmware/fw_payload.elf \
		-trace events=trace-events,file=trace.log


# bootloader
###########
build/bootloader:
	mkdir -p build/bootloader

bootloaderdist: build/bootloader/qemu.coe build/bootloader/board.coe
	cd build; zip -r bootloader.zip bootloader

toolchain/bootloader/linux/build/bootloader_{qemu,board}.elf: toolchain/bootloader/linux
	cd toolchain/bootloader/linux; make

build/bootloader/qemu.elf: toolchain/bootloader/linux/build/bootloader_qemu.elf build/bootloader
	cp toolchain/bootloader/linux/build/bootloader_qemu.elf build/bootloader/qemu.elf

build/bootloader/qemu.bin: build/bootloader/qemu.elf
	yokyo_elf2bin build/bootloader/qemu.elf build/bootloader/qemu.bin

build/bootloader/qemu.coe: build/bootloader/qemu.bin
	yokyo_bin2coe build/bootloader/qemu.bin > build/bootloader/qemu.coe

build/bootloader/board.elf: toolchain/bootloader/linux/build/bootloader_board.elf build/linux
	cp toolchain/bootloader/linux/build/bootloader_board.elf build/bootloader/board.elf

build/bootloader/board.bin: build/bootloader/board.elf
	yokyo_elf2bin build/bootloader/board.elf build/bootloader/board.bin

build/bootloader/board.coe: build/bootloader/board.bin
	yokyo_bin2coe build/bootloader/board.bin > build/bootloader/board.coe

# tests
run-bootloader: build/bootloader/qemu.elf build/linux/kernel.img.bin
	 qemu-system-riscv32 \
		-machine virt \
		-bios none \
		-smp 1 \
		-nographic \
		-kernel build/bootloader/qemu.elf \
		-drive file=build/linux/kernel.img.bin,if=none,format=raw,id=x0 \
		-device virtio-blk-device,drive=x0,bus=virtio-mmio-bus.0 \
		-trace events=trace-events,file=trace.log

run-bootloader-gdb: build/bootloader/qemu.elf build/linux/kernel.img.bin
	 qemu-system-riscv32 \
		-machine virt \
		-bios none \
		-smp 1 \
		-nographic \
		-kernel build/bootloader/qemu.elf \
		-drive file=build/linux/kernel.bin,if=none,format=raw,id=x0 -device virtio-blk-device,drive=x0,bus=virtio-mmio-bus.0 \
		-S -gdb tcp::11451

# busybox
###########
busybox/.config: conf/busybox.config
	cp conf/busybox.config busybox/.config

busybox/_install: busybox/.config
	cd busybox; make ARCH=riscv CROSS_COMPILE=riscv32-unknown-linux-gnu- CFLAGS="-mabi=ilp32 -march=rv32ima" install

busybox/initramfs.cpio.gz busybox/rootfs.img: busybox/.config busybox/_install busybox/scripts/buildfs.sh
	./busybox/scripts/buildfs.sh

# utils
###########
gdb:
	riscv32-unknown-elf-gdb

install:
	cd qemu; ./configure --target-list=riscv32-softmmu; make -j 4; sudo make install
	cd riscv-gnu-toolchain; ./configure --prefix=/opt/riscv32 --with-arch=rv32ima --with-abi=ilp32; make newlib -j 4; make linux -j 4
	cd toolchain; pip install . --upgrade

clean:
	rm -rf build

	cd linux; make clean ARCH=riscv CROSS_COMPILE=riscv32-unknown-linux-gnu-;
	cd linux; rm arch/riscv/boot/Image

	cd busybox; rm rootfs.img; make clean
	cd opensbi; make clean

	cd xv6-riscv; make clean

	cd toolchain/bootloader/xv6; make clean
	cd toolchain/bootloader/linux; make clean
