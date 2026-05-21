# 🦎 My Own Kernel (Zig Edition)

![Zig](https://img.shields.io/badge/Made%20with-Zig-orange?style=for-the-badge&logo=zig)
![Assembly](https://img.shields.io/badge/Arch-x86__64-blue?style=for-the-badge&logo=intel)

An experimental kernel written from scratch, focusing on modernity and memory safety. Initially conceived in C, the project was **migrated to Zig** to explore modern language features in low-level development (OSDev).

The goal is to build a small x86_64 operating system compatible with Multiboot, implementing memory management, interrupts, and basic drivers.

---

## 📸 Screenshots

> *Current state of the kernel running in QEMU, displaying the initialization of the Memory Management Subsystem.*

![Kernel Screenshot](./docs/print.png)

---

## 🚀 Project Status

The kernel is in the **Context switch preparation** phase.

### ✅ Implemented
- [x] **Bootloader:** Multiboot support (GRUB) via Assembly (`multiboot_header.asm`).
- [x] **Kernel Entry:** Entry point migrated to Zig (`kernel/main.zig`).
- [x] **VGA Driver:** Complete implementation in Zig with color and string support (`kernel/drivers/vga.zig`).
- [x] **IDT (Interrupt Descriptor Table):** Basic interrupt and exception handling implemented in Zig.
- [x] **Multiboot Parsing:** Memory map reading provided by BIOS/GRUB.
- [x] **PMM (Physical Memory Manager):**
  - Physical page allocator (4KB).
  - **Bitmap** used to track free/used memory.
  - Kernel and Bitmap memory protection.
- [x] **VMM (Virtual Memory Manager):** Paging and virtual memory mapping.
- [x] **Heap Allocator:** Implementation of `kmalloc` and `kfree`.
- [x] **GDT (Global Descriptor Table):** GDT refinement in Zig.
- [x] **PIC:** Hardware interrupt management.

### 🚧 In Progress

- [ ] **Multithreading:** Thread management and context switching.

---

## 🛠️ How to Compile and Run

### Dependencies
To compile this project, you will need the following tools installed on your Linux (Manjaro/Arch or similar):

* **Zig** (Main compiler)
* **NASM** (Assembler for boot stubs)
* **QEMU** (Emulator for testing)
* **GRUB / xorriso** (To create the bootable ISO image)
* **Linker (`ld`)** (Usually part of binutils)

### Commands (Makefile)

The project uses a `Makefile` to streamline the development workflow:

```bash
# Compile the entire kernel and generate the ISO
make all

# Compile and immediately run in QEMU
make run

# Clean build artifacts (.o, .elf, .iso)
make clean

# Run in Debug mode (waits for GDB connection)
make debug

```

---

## 📂 Project Structure

```text
/
├── kernel/
│   ├── arch/x86/        # Architecture-specific code (Assembly/GDT/IDT)
│   ├── mm/              # Memory Management (Heap, VMM, PMM, Bitmap)
│   ├── drivers/         # General drivers (Keyboard, Video, Timer)
│   ├── utils/           # Kernel utilities (Logger)
│   ├── main.zig         # Kernel entry point
│   └── multiboot.zig    # Multiboot header parsing
├── linker.ld            # Linker script
└── Makefile             # Build automation
```
