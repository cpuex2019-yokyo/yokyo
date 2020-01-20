default: run

update:
	git submodule update --remote

configure:
	cd linux; make ARCH=riscv CROSS_COMPILE=riscv32-unknown-linux-gnu- menuconfig
	cp linux/.config conf/linux.config

linux/.config: conf/linux.config
	cp conf/linux.config linux/.config

linux/arch/riscv/boot/Image: linux/.config
	cd linux; make ARCH=riscv CROSS_COMPILE=riscv32-unknown-linux-gnu- vmlinux Image -j 4  

busybox/.config: conf/busybox.config
	cp conf/busybox.config busybox/.config

busybox/_install: busybox/.config
	cd busybox; make ARCH=riscv CROSS_COMPILE=riscv32-unknown-linux-gnu- install

busybox/rootfs.img:	 busybox/.config busybox/_install
	./busybox/scripts/buildfs.sh

opensbi/build/platform/qemu/virt/firmware/fw_payload.elf: linux/arch/riscv/boot/Image
	cd opensbi; make CROSS_COMPILE=riscv32-unknown-elf- PLATFORM=qemu/virt PLATFORM_RISCV_ABI=ilp32 PLATFORM_RISCV_ISA=rv32ima FW_PAYLOAD_PATH=../linux/arch/riscv/boot/Image

# Main utils
run: busybox/rootfs.img opensbi/build/platform/qemu/virt/firmware/fw_payload.elf
	sudo qemu-system-riscv32 -nographic -machine virt\
		-kernel opensbi/build/platform/qemu/virt/firmware/fw_payload.elf \
		-append "root=/dev/vda rw console=ttyS0" \
		-drive file=busybox/rootfs.img,format=raw,id=hd0 \
		-device virtio-blk-device,drive=hd0

install:
	cd qemu; ./configure --target-list=riscv32-softmmu; make -j 4; sudo make install
	cd riscv-gnu-toolchain; ./configure --prefix=/opt/riscv32 --with-arch=rv32ima --with-abi=ilp32; make newlib -j 4; make linux -j 4

clean:
	cd busybox; rm rootfs.img; make clean
	cd linux; make clean ARCH=riscv CROSS_COMPILE=riscv32-unknown-linux-gnu-; rm arch/riscv/boot/Image # TODO
	cd opensbi; make clean
