default: run

update:
	git submodule update --remote

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

build/initramfs.cpio.gz: build busybox/rootfs.img

toolchain/xv6_bootloader/build/bootloader:
	cd toolchain/xv6_bootloader; make

xv6_coe: build/xv6/kernel.coe build/xv6/fs.coe build/xv6/bootloader.coe

xv6_dist: xv6_coe
	cd build; zip -r xv6_deploy.zip xv6

build/xv6/bootloader.bin: toolchain/xv6_bootloader/build/bootloader build/xv6
	cp toolchain/xv6_bootloader/build/bootloader build/xv6/bootloader.bin

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

build/xv6/kernel.bin: xv6-riscv/kernel/kernel build/xv6
	cp xv6-riscv/kernel/kernel build/xv6/kernel.bin

build/xv6/kernel.coe: build/xv6/kernel.bin build/xv6
	yokyo_bin2coe build/xv6/kernel.bin > build/xv6/kernel.coe

build:
	mkdir -p build

build/xv6:
	mkdir -p build/xv6

opensbi/build/platform/qemu/virt/firmware/fw_payload.elf: linux/arch/riscv/boot/Image build
	cd opensbi; make CROSS_COMPILE=riscv32-unknown-elf- PLATFORM=qemu/virt PLATFORM_RISCV_ABI=ilp32 PLATFORM_RISCV_ISA=rv32ima FW_PAYLOAD_PATH=../linux/arch/riscv/boot/Image

# Main utils
run: busybox/rootfs.img opensbi/build/platform/qemu/virt/firmware/fw_payload.elf
	sudo qemu-system-riscv32 -nographic -machine virt \
		-kernel opensbi/build/platform/qemu/virt/firmware/fw_payload.elf \
		-append "root=/dev/vda rw console=ttyS0" \
		-drive file=busybox/rootfs.img,format=raw,id=hd0 \
		-device virtio-blk-device,drive=hd0

run-mem: build/initramfs.cpio.gz opensbi/build/platform/qemu/virt/firmware/fw_payload.elf
	sudo qemu-system-riscv32 -nographic -machine virt \
		-kernel opensbi/build/platform/qemu/virt/firmware/fw_payload.elf \
		-initrd build/initramfs.cpio.gz \
		-append "console=ttyS0" \

run-gdb: build/initramfs.cpio.gz opensbi/build/platform/qemu/virt/firmware/fw_payload.elf
	sudo qemu-system-riscv32 -nographic -machine virt \
		-kernel build/linux/platform/qemu/virt/firmware/fw_payload.elf \
		-append "root=/dev/vda rw console=ttyS0" \
		-drive file=busybox/rootfs.img,format=raw,id=hd0 \
		-device virtio-blk-device,drive=hd0 \
		-S -gdb tcp::11451

install:
	cd qemu; ./configure --target-list=riscv32-softmmu; make -j 4; sudo make install
	cd riscv-gnu-toolchain; ./configure --prefix=/opt/riscv32 --with-arch=rv32ima --with-abi=ilp32; make newlib -j 4; make linux -j 4

clean:
	rm -rf build
	cd busybox; rm rootfs.img; make clean
	cd linux; make clean ARCH=riscv CROSS_COMPILE=riscv32-unknown-linux-gnu-;
	cd linux; rm arch/riscv/boot/Image
	cd opensbi; make clean
