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
KERNEL_ELF = zig-out/bin/kernel.elf
UEFI_DISK = disk
UEFI_FILE = $(UEFI_DISK)/EFI/BOOT/BOOTX64.EFI
KERNEL_BIN = $(UEFI_DISK)/kernel.bin

.PHONY: all run debug clean info

all: $(UEFI_FILE) $(KERNEL_BIN)

# --- COMPILATION RULES ---

$(KERNEL_BIN): $(KERNEL_DIR)/boot/bootinfo.zig $(KERNEL_SOURCES)
	@mkdir -p $(UEFI_DISK)
	zig build -Dkbuild=Binary
	cp zig-out/bin/kernel.bin $(KERNEL_BIN)
	ls -l $(KERNEL_BIN)

$(UEFI_FILE): $(UEFI_SOURCES)
	@mkdir -p $(UEFI_DISK)/EFI/BOOT
	zig build -Duefi=true
	cp zig-out/bin/BOOTX64.efi $(UEFI_FILE)

run: $(UEFI_FILE) $(KERNEL_BIN) $(UEFI_BIOS) $(UEFI_DISK)
	qemu-system-x86_64 -bios $(UEFI_BIOS) \
		-drive format=raw,file=fat:rw:$(UEFI_DISK) -net none \
		-serial stdio -display none \
		-smp 4

debug: $(UEFI_FILE) $(KERNEL_BIN) $(UEFI_BIOS) $(UEFI_DISK)
	qemu-system-x86_64 -bios $(UEFI_BIOS) \
		-drive format=raw,file=fat:rw:$(UEFI_DISK) -net none \
		-serial stdio -display none \
		-smp 4 \
		-d int -no-reboot -no-shutdown

# Shows which files Make is seeing (Makefile Debug)
info:
	@echo "Zig sources found: $(KERNEL_SOURCES)"
	@echo "UEFI bootloader sources found: $(UEFI_SOURCES)"
	@echo "Kernel Directory: $(KERNEL_DIR)"

clean:
	rm -rf $(UEFI_DISK) zig-out .zig-cache
