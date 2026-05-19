ASM = nasm
CC = gcc
ZIG = zig

# --- DIRECTORIES ---
SRC_DIR = .
KERNEL_DIR = $(SRC_DIR)/kernel
ASM_DIR = $(KERNEL_DIR)/arch/x86
BUILD_DIR = build
ISO_DIR = root_iso

# --- FILES ---
# Assembly
INIT_KERNEL_FILES = $(ASM_DIR)/init/starter.asm 
MULTIBOOT_FILE = $(ASM_DIR)/init/multiboot_header.asm

# Zig: Recursively find all .zig files inside kernel/
KERNEL_SOURCES = $(shell find $(KERNEL_DIR) -name "*.zig")
UEFI_SOURCES = $(shell find ./boot -name "*.zig")
UEFI_BIOS = /usr/share/edk2/x64/OVMF.4m.fd

# Generated Objects
OBJ_ASM_START = $(BUILD_DIR)/starter.o
OBJ_ASM_MULTI = $(BUILD_DIR)/multiboot_header.o
OBJ_ZIG_MAIN = zig-out/bin/kernel.o

# Final Binary
# KERNEL_ELF = $(BUILD_DIR)/kernel.elf
KERNEL_ELF = zig-out/bin/kernel.elf
KERNEL_BIN = disk/kernel.bin
ISO_FILE = kernel.iso
UEFI_FILE = disk/EFI/BOOT/BOOTX64.EFI
UEFI_DISK = disk
LINKER_SCRIPT = linker.ld

.PHONY: all run debug clean info

all: $(ISO_FILE) $(UEFI_FILE) $(KERNEL_BIN)

# --- COMPILATION RULES ---

$(ISO_FILE): $(KERNEL_ELF)
	@echo "[ISO] Generating $(ISO_FILE)..."
	@mkdir -p $(ISO_DIR)/boot/grub
	cp $(KERNEL_ELF) $(ISO_DIR)/boot/
	grub-mkrescue -o $(ISO_FILE) $(ISO_DIR)

$(KERNEL_ELF): $(OBJ_ASM_START) $(OBJ_ASM_MULTI) $(OBJ_ZIG_MAIN) $(LINKER_SCRIPT)
	@echo "[LINK] Generating Final Kernel..."
	ld -m elf_x86_64 -T $(LINKER_SCRIPT) -o $(KERNEL_ELF) $(OBJ_ASM_START) $(OBJ_ASM_MULTI) $(OBJ_ZIG_MAIN)

$(OBJ_ASM_START): $(INIT_KERNEL_FILES)
	@mkdir -p $(BUILD_DIR)
	@echo "[ASM] Compiling starter.asm..."
	$(ASM) -f elf64 -g $(INIT_KERNEL_FILES) -o $(OBJ_ASM_START)

$(OBJ_ASM_MULTI): $(MULTIBOOT_FILE)
	@mkdir -p $(BUILD_DIR)
	@echo "[ASM] Compiling multiboot_header.asm..."
	$(ASM) -f elf64 -g $(MULTIBOOT_FILE) -o $(OBJ_ASM_MULTI)

$(OBJ_ZIG_MAIN): $(KERNEL_SOURCES)
	@mkdir -p $(BUILD_DIR)
	@echo "[ZIG] Compiling sources..."
	zig build -Dkbuild=Object

$(KERNEL_BIN): $(KERNEL_SOURCES)
	@mkdir -p $(UEFI_DISK)
	zig build -Dkbuild=Binary
	cp zig-out/bin/kernel.bin $(KERNEL_BIN)
	ls -l $(KERNEL_BIN)

$(UEFI_FILE): $(UEFI_SOURCES)
	@mkdir -p $(UEFI_DISK)/EFI/BOOT
	zig build -Duefi=true
	cp zig-out/bin/BOOTX64.efi $(UEFI_FILE)

run: $(ISO_FILE)
	qemu-system-x86_64 -drive format=raw,file=$(ISO_FILE) -serial stdio

run-uefi: $(UEFI_FILE) $(KERNEL_BIN) $(UEFI_BIOS) $(UEFI_DISK)
	qemu-system-x86_64 -bios $(UEFI_BIOS) -drive format=raw,file=fat:rw:$(UEFI_DISK) -net none -serial stdio -display none

debug: $(ISO_FILE)
	qemu-system-x86_64 -drive format=raw,file=$(ISO_FILE) -s -S -d int -serial stdio -debugcon stdio

# Shows which files Make is seeing (Makefile Debug)
info:
	@echo "Zig sources found: $(KERNEL_SOURCES)"
	@echo "Kernel Directory: $(KERNEL_DIR)"

clean:
	rm -f $(ISO_FILE)
	rm -f $(ISO_DIR)/boot/*.elf
	rm -rf $(BUILD_DIR) $(UEFI_DISK) zig-out .zig-cache
