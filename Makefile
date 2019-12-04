default: run


linux/.config: conf/linux.config
	cp conf/linux.config linux/.config

linux/arch/riscv/boot/Image: linux/.config
	cd linux; make ARCH=riscv CROSS_COMPILE=riscv32-unknown-linux-gnu- arch/riscv/boot/Image -j 4  

busybox/.config: conf/busybox.config
	cp conf/busybox.config busybox/.config

busybox/_install: busybox/.config
	cd busybox; make ARCH=riscv CROSS_COMPILE=riscv32-unknown-linux-gnu- install

busybox/rootfs.img:	 busybox/.config busybox/_install
	./busybox/scripts/buildfs.sh

opensbi/build/platform/qemu/virt/firmware/fw_payload.elf: linux/arch/riscv/boot/Image
	cd opensbi; make CROSS_COMPILE=riscv32-unknown-elf- PLATFORM=qemu/virt PLATFORM_RISCV_ABI=ilp32d FW_PAYLOAD_PATH=../linux/arch/riscv/boot/Image

# Main utils
run: busybox/rootfs.img opensbi/build/platform/qemu/virt/firmware/fw_payload.elf
	sudo qemu-system-riscv32 -nographic -machine virt\
		-kernel opensbi/build/platform/qemu/virt/firmware/fw_payload.elf \
		-append "root=/dev/vda rw console=ttyS0" \
		-drive file=busybox/rootfs.img,format=raw,id=hd0 \
		-device virtio-blk-device,drive=hd0

install:
	cd qemu; ./configure --target-list=riscv32-softmmu; make -j 4; sudo make install
	cd riscv-gnu-toolchain; ./configure --prefix=/opt/riscv32 --with-arch=rv32gc --with-abi=ilp32d; make newlib -j 4; make linux -j 4

clean:
	cd busybox; rm rootfs.img; make clean
	cd linux; make clean ARCH=riscv CROSS_COMPILE=riscv32-unknown-linux-gnu-
