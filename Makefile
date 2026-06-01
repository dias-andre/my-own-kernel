# --- DIRECTORIES ---
SRC_DIR = .
KERNEL_DIR = $(SRC_DIR)/kernel
BUILD_DIR = build

# Zig: Recursively find all .zig files inside kernel/
KERNEL_SOURCES = $(shell find $(KERNEL_DIR) -name "*.zig")
UEFI_SOURCES = $(shell find $(KERNEL_DIR)/boot -name "*.zig")
UEFI_BIOS = /usr/share/edk2/x64/OVMF.4m.fd

# Final Binary
# KERNEL_ELF = $(BUILD_DIR)/kernel.elf
UEFI_FILE = zig-out/bin/BOOTX64.efi
KERNEL_ELF = zig-out/bin/kernel.elf

IMAGE_FILE=disk.img
.PHONY: all run debug clean info

all: $(UEFI_FILE) $(KERNEL_ELF) $(IMAGE_FILE)

# --- COMPILATION RULES ---

$(KERNEL_ELF): $(KERNEL_DIR)/boot/bootinfo.zig $(KERNEL_SOURCES)
	@echo "Compiling $(KERNEL_ELF)"
	zig build
	ls -l $(KERNEL_ELF)

$(UEFI_FILE): $(UEFI_SOURCES)
	@echo "Building UEFI file $(UEFI_FILE)"
	zig build -Duefi=true
	ls -la $(UEFI_FILE)

$(IMAGE_FILE): $(UEFI_FILE) $(KERNEL_ELF)
	@echo "Creating a FAT32 image with 64MB"
	dd if=/dev/zero of=$(IMAGE_FILE) bs=1M count=64 status=none
	mformat -i $(IMAGE_FILE) -F ::
	mmd -i $(IMAGE_FILE) ::/EFI
	mmd -i $(IMAGE_FILE) ::/EFI/BOOT
	mcopy -i $(IMAGE_FILE) $(UEFI_FILE) ::/EFI/BOOT/BOOTX64.EFI
	mcopy -i $(IMAGE_FILE) $(KERNEL_ELF) ::/kernel.elf

run: $(IMAGE_FILE) $(UEFI_BIOS)
	qemu-system-x86_64 -bios $(UEFI_BIOS) \
		-drive format=raw,file=$(IMAGE_FILE) -net none \
		-serial stdio -smp 4

debug: $(IMAGE_FILE) $(UEFI_BIOS)
	qemu-system-x86_64 -bios $(UEFI_BIOS) \
		-drive format=raw,file=$(IMAGE_FILE) -net none \
		-serial stdio -smp 4 -no-reboot -d int

# Shows which files Make is seeing (Makefile Debug)
info:
	@echo "Current Zig version: $(shell zig version) (recomended: 0.15)"
	@echo "Zig sources found: $(KERNEL_SOURCES)"
	@echo "UEFI bootloader sources found: $(UEFI_SOURCES)"
	@echo "Kernel Directory: $(KERNEL_DIR)"

clean:
	rm -rf zig-out .zig-cache $(IMAGE_FILE)
