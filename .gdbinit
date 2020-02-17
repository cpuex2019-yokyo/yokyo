set confirm off
set architecture riscv:rv32
target remote 127.0.0.1:11451
symbol-file opensbi/build/platform/qemu/virt/firmware/fw_payload.elf
set disassemble-next-line auto
