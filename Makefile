default: run

update:
	git submodule update --remote

build:
	mkdir -p build

# xv6
toolchain/bootloader/xv6/build/bootloader:
	cd toolchain/bootloader/xv6; make

xv6coe: build/xv6/kernel.coe build/xv6/fs.coe build/xv6/bootloader.coe

xv6dist: xv6coe
	cd build; zip -r xv6_deploy.zip xv6

build/xv6/bootloader.elf: toolchain/bootloader/xv6/build/bootloader build/xv6
	cp toolchain/bootloader/xv6/build/bootloader build/xv6/bootloader.elf

build/xv6/bootloader.bin: build/xv6/bootloader.elf
	yokyo_elf2bin build/xv6/bootloader.elf build/xv6/bootloader.bin

build/xv6/bootloader.coe: build/xv6/bootloader.bin build/xv6
	yokyo_bin2coe build/xv6/bootloader.bin > build/xv6/bootloader.coe

xv6-riscv/fs.img: 
	cd xv6-riscv; make fs.img

build/xv6/fs.bin: xv6-riscv/fs.img build/xv6
	cp xv6-riscv/fs.img build/xv6/fs.bin

build/xv6/fs.coe: build/xv6/fs.bin build/xv6
	yokyo_bin2coe build/xv6/fs.bin > build/xv6/fs.coe

xv6-riscv/kernel/kernel: 
	cd xv6-riscv; make kernel/kernel

build/xv6/kernel.elf: xv6-riscv/kernel/kernel build/xv6
	cp xv6-riscv/kernel/kernel build/xv6/kernel.elf

build/xv6/kernel.bin: build/xv6/kernel.elf
	yokyo_elf2bin build/xv6/kernel.elf build/xv6/kernel.bin

build/xv6/kernel.coe: build/xv6/kernel.bin build/xv6
	yokyo_bin2coe build/xv6/kernel.bin > build/xv6/kernel.coe

build/xv6:
	mkdir -p build/xv6

# linux

toolchain/bootloader/linux/build/bootloader:
	cd toolchain/bootloader/linux; make

linuxcoe: build/linux/kernel.coe build/linux/fs.coe build/linux/bootloader.coe

linuxdist: linuxcoe
	cd build; zip -r linux_deploy.zip linux

build/linux/bootloader.elf: toolchain/bootloader/linux/build/bootloader build/linux
	cp toolchain/bootloader/linux/build/bootloader build/linux/bootloader.elf

build/linux/bootloader.bin: build/linux/bootloader.elf
	yokyo_elf2bin build/linux/bootloader.elf build/linux/bootloader.bin

build/linux/bootloader.coe: build/linux/bootloader.bin build/linux
	yokyo_bin2coe build/linux/bootloader.bin > build/linux/bootloader.coe

build/linux:
	mkdir -p build/linux

configure:
	cp conf/linux.config linux/.config
	cd linux; make ARCH=riscv CROSS_COMPILE=riscv32-unknown-linux-gnu- menuconfig
	cp linux/.config conf/linux.config

linux/.config: conf/linux.config
	cp conf/linux.config linux/.config

linux/arch/riscv/boot/Image: linux
	cd linux; make ARCH=riscv CROSS_COMPILE=riscv32-unknown-linux-gnu- vmlinux Image -j 4  

busybox/.config: conf/busybox.config
	cp conf/busybox.config busybox/.config

busybox/_install: busybox/.config
	cd busybox; make ARCH=riscv CROSS_COMPILE=riscv32-unknown-linux-gnu- CFLAGS="-mabi=ilp32 -march=rv32ima" install

busybox/rootfs.img:	 busybox/.config busybox/_install busybox/scripts/templates
	./busybox/scripts/buildfs.sh

opensbi/build/platform/qemu/virt/firmware/fw_payload.elf: linux/arch/riscv/boot/Image build
	cd opensbi; make CROSS_COMPILE=riscv32-unknown-elf- PLATFORM=qemu/virt PLATFORM_RISCV_ABI=ilp32 PLATFORM_RISCV_ISA=rv32ima FW_PAYLOAD_PATH=../linux/arch/riscv/boot/Image

# Main utils
run: busybox/initramfs.cpio.gz opensbi/build/platform/qemu/virt/firmware/fw_payload.elf
	sudo qemu-system-riscv32 \
		-nographic \
		-machine virt \
		-append "console=ttyS0" \
		-kernel opensbi/build/platform/qemu/virt/firmware/fw_payload.elf \
		-trace events=trace-events,file=trace.log

run-gdb: busybox/initramfs.cpio.gz opensbi/build/platform/qemu/virt/firmware/fw_payload.elf
	sudo qemu-system-riscv32 \
		-nographic \
		-machine virt \
		-append "console=ttyS0" \
		-kernel opensbi/build/platform/qemu/virt/firmware/fw_payload.elf \
		-trace events=trace-events,file=trace.log \
		-S -gdb tcp::11451

gdb:
	riscv32-unknown-elf-gdb

install:
	cd qemu; ./configure --target-list=riscv32-softmmu; make -j 4; sudo make install
	cd riscv-gnu-toolchain; ./configure --prefix=/opt/riscv32 --with-arch=rv32ima --with-abi=ilp32; make newlib -j 4; make linux -j 4

clean:
	rm -rf build
	cd busybox; rm rootfs.img; make clean
	cd linux; make clean ARCH=riscv CROSS_COMPILE=riscv32-unknown-linux-gnu-;
	cd linux; rm arch/riscv/boot/Image
	cd opensbi; make clean
