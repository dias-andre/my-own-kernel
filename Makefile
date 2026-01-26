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

# Generated Objects
OBJ_ASM_START = $(BUILD_DIR)/starter.o
OBJ_ASM_MULTI = $(BUILD_DIR)/multiboot_header.o
OBJ_ZIG_MAIN  = $(BUILD_DIR)/main.o

# Final Binary
KERNEL_ELF = $(BUILD_DIR)/kernel.elf
ISO_FILE = kernel.iso
LINKER_SCRIPT = linker.ld

.PHONY: all run debug clean info

all: $(ISO_FILE)

# --- COMPILATION RULES ---

# 1. Create ISO image (Depends on Linked Kernel)
$(ISO_FILE): $(KERNEL_ELF)
	@echo "[ISO] Generating $(ISO_FILE)..."
	@mkdir -p $(ISO_DIR)/boot/grub
	cp $(KERNEL_ELF) $(ISO_DIR)/boot/
	grub-mkrescue -o $(ISO_FILE) $(ISO_DIR)

# 2. Linking (Depends on ASM and Zig Objects)
$(KERNEL_ELF): $(OBJ_ASM_START) $(OBJ_ASM_MULTI) $(OBJ_ZIG_MAIN) $(LINKER_SCRIPT)
	@echo "[LINK] Generating Final Kernel..."
	ld -m elf_x86_64 -T $(LINKER_SCRIPT) -o $(KERNEL_ELF) $(OBJ_ASM_START) $(OBJ_ASM_MULTI) $(OBJ_ZIG_MAIN)

# 3. Assembly Compilation (Starter)
$(OBJ_ASM_START): $(INIT_KERNEL_FILES)
	@mkdir -p $(BUILD_DIR)
	@echo "[ASM] Compiling starter.asm..."
	$(ASM) -f elf64 -g $(INIT_KERNEL_FILES) -o $(OBJ_ASM_START)

# 4. Assembly Compilation (Multiboot)
$(OBJ_ASM_MULTI): $(MULTIBOOT_FILE)
	@mkdir -p $(BUILD_DIR)
	@echo "[ASM] Compiling multiboot_header.asm..."
	$(ASM) -f elf64 -g $(MULTIBOOT_FILE) -o $(OBJ_ASM_MULTI)

# 5. Zig Compilation (THE MAGIC HAPPENS HERE)
# This rule says: "If any .zig file changes, recompile main.o"
$(OBJ_ZIG_MAIN): $(KERNEL_SOURCES)
	@mkdir -p $(BUILD_DIR)
	@echo "[ZIG] Compiling sources..."
	$(ZIG) build-obj $(KERNEL_DIR)/main.zig \
		-target x86_64-freestanding \
		-mcpu=x86_64-soft_float \
		-fno-stack-check \
		-O ReleaseSafe \
		-femit-bin=$(OBJ_ZIG_MAIN)

# --- UTILITIES ---

run: $(ISO_FILE)
	qemu-system-x86_64 -drive format=raw,file=$(ISO_FILE)

debug: $(ISO_FILE)
	qemu-system-x86_64 -drive format=raw,file=$(ISO_FILE) -s -S -d int

# Shows which files Make is seeing (Makefile Debug)
info:
	@echo "Zig sources found: $(KERNEL_SOURCES)"
	@echo "Kernel Directory: $(KERNEL_DIR)"

clean:
	rm -rf $(BUILD_DIR)/*
	rm -f $(ISO_FILE)
	rm -f $(ISO_DIR)/boot/*.elf