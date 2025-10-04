ASM = nasm
CC = gcc
SRC_DIR = .
ASM_DIR = $(SRC_DIR)/arch/x86
BUILD_DIR = build
BOOTSTRAP_FILE = $(ASM_DIR)/init/bootstrap.asm
INIT_KERNEL_FILES = $(ASM_DIR)/init/starter.asm 
MULTIBOOT_FILE = $(ASM_DIR)/init/multiboot_header.asm
KERNEL_FILES = $(SRC_DIR)/kernel/main.c
INCLUDE_DIRS = $(shell find include -type d)

KERNEL_OBJECT = $(BUILD_DIR)/kernel.elf
OUTFILE = square-kernel.iso
LINKER = linker.ld

LINKER_FILES_64 = $(BUILD_DIR)/idt.o $(BUILD_DIR)/interrupts.o \
 $(KERNEL_OBJECT) $(BUILD_DIR)/vga_buffer.elf $(BUILD_DIR)/liballoc.o \
 $(BUILD_DIR)/string.o $(BUILD_DIR)/MMU.o  $(BUILD_DIR)/spinlock.o $(BUILD_DIR)/paging.o
 
LINKER_FILES_32 = $(BUILD_DIR)/multiboot_header.o $(BUILD_DIR)/starter.o $(BUILD_DIR)/thread.o

KERNEL_FLAGS_64 = -g -Wno-error=incompatible-pointer-types  -Wno-error=int-conversion -fno-stack-protector -c \
 -ffreestanding -fno-asynchronous-unwind-tables -fno-pie -Wint-conversion -Wint-to-pointer-cast $(addprefix -I,$(INCLUDE_DIRS))

ALL_LINKER_FILES = $(LINKER_FILES_32) $(LINKER_FILES_64)

build64: $(INIT_KERNEL_FILES) $(BOOTSTRAP_FILE) $(KERNEL_FILES)
	$(ASM) -f elf64 -g $(INIT_KERNEL_FILES) -o $(BUILD_DIR)/starter.o
	$(ASM) -f elf64 -g $(MULTIBOOT_FILE) -o $(BUILD_DIR)/multiboot_header.o
	$(ASM) -f elf64 -g $(ASM_DIR)/idt.asm -o $(BUILD_DIR)/idt.o

	$(CC) $(KERNEL_FLAGS_64) $(SRC_DIR)/kernel/thread.c -o $(BUILD_DIR)/thread.o
	$(CC) $(KERNEL_FLAGS_64) $(KERNEL_FILES) -o $(KERNEL_OBJECT)
	$(CC) $(KERNEL_FLAGS_64) $(SRC_DIR)/kernel/interrupts.c -o $(BUILD_DIR)/interrupts.o
	$(CC) $(KERNEL_FLAGS_64) $(SRC_DIR)/vga/vga_buffer.c -o $(BUILD_DIR)/vga_buffer.elf
	$(CC) $(KERNEL_FLAGS_64) $(SRC_DIR)/mm/liballoc.c -o $(BUILD_DIR)/liballoc.o
	$(CC) $(KERNEL_FLAGS_64) $(SRC_DIR)/mm/MMU.c -o $(BUILD_DIR)/MMU.o
	$(CC) $(KERNEL_FLAGS_64) lib/string.c -o $(BUILD_DIR)/string.o
	$(CC) $(KERNEL_FLAGS_64) $(SRC_DIR)/mm/spinlock.c -o $(BUILD_DIR)/spinlock.o
	$(CC) $(KERNEL_FLAGS_64) $(SRC_DIR)/mm/paging/paging.c -o $(BUILD_DIR)/paging.o
	
	ld -m elf_x86_64 -T linker.ld -o $(BUILD_DIR)/square-kernel.elf $(ALL_LINKER_FILES)

	# Preparando para o GRUB
	cp $(BUILD_DIR)/square-kernel.elf root_iso/boot/

	grub2-mkrescue -o square-kernel.iso root_iso

run: $(OUTFILE)
	qemu-system-x86_64 -drive format=raw,file=$(OUTFILE)

debug: $(OUTFILE)
	qemu-system-x86_64 -drive format=raw,file=$(OUTFILE) -s -S -d int

clean:
	rm -rf $(BUILD_DIR)/*
	rm -f $(OUTFILE)
