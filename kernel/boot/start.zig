const std = @import("std");
const paging = @import("./bootstrap_paging.zig");
const uefi = std.os.uefi;
const BootInfo = @import("bootinfo").BootInfo;

const MAX_KERNEL_ALLOCATION: usize = 0x4000000;
const KernelEntryFn = *const fn (info: *BootInfo) callconv(.{ .x86_64_sysv = .{} }) noreturn;

fn serial_print(str: []const u8) void {
    for (str) |char| {
        asm volatile ("outb %[value], %[port]"
            :
            : [value] "{al}" (char),
              [port] "{dx}" (@as(u16, 0x3f8)),
        );
    }
}

var pml4_table: [*]u64 = undefined;

fn init_page_directory(boot_services: *uefi.tables.BootServices) !void {
    const pml4_ptr = try boot_services.allocatePages(.{ .max_address = @ptrFromInt(paging.MAX_ALLOCATION_ADDR) }, .loader_data, 1);
    pml4_table = @ptrCast(@alignCast(pml4_ptr));
    const pml4_bytes: [*]u8 = @ptrCast(pml4_ptr);
    @memset(pml4_bytes[0..4096], 0);
}

fn map_ram(limit: usize) !void {
    uefi_print("Start identity mapping...\n", .{});
    uefi_print("Map limit: 0x{x}\n", .{limit});
    var current_offset: usize = 0;
    while (current_offset < limit) : (current_offset += 4096) {
        try paging.map_page(@ptrCast(@alignCast(pml4_table)), current_offset, current_offset, paging.PAGE_PRESENT | paging.PAGE_RW);
    }
    uefi_print("Map complete!\n", .{});
}

fn map_kernel_vma(kernel_size: usize, phys_base: usize, min_vaddr: usize) !void {
    const flags = paging.PAGE_PRESENT | paging.PAGE_RW;
    var virt_addr: usize = min_vaddr;
    var phys_addr: usize = phys_base;
    const end_virt_addr = virt_addr + kernel_size;
    while (virt_addr < end_virt_addr) : ({
        virt_addr += 4096;
        phys_addr += 4096;
    }) {
        try paging.map_page(@ptrCast(@alignCast(pml4_table)), virt_addr, phys_addr, flags);
    }
}

const KernelMemoryData = struct {
    kernel_vma: usize,
    kernel_lma: usize,
    kernel_size: usize,
};

fn load_elf(file_buffer: []align(8) const u8, boot_services: *uefi.tables.BootServices) !KernelMemoryData {
    const header: *const std.elf.Elf64_Ehdr = @ptrCast(file_buffer.ptr);
    if (!std.mem.eql(u8, header.e_ident[0..4], "\x7fELF")) {
        return error.InvalidMagic;
    }

    if (header.e_machine != std.elf.EM.X86_64) return error.InvalidMachine;

    var min_vaddr: u64 = std.math.maxInt(u64);
    var max_vaddr: u64 = 0;
    const ph_table_start = file_buffer.ptr + header.e_phoff;
    const ph_table: [*]const std.elf.Elf64_Phdr = @ptrCast(@alignCast(ph_table_start));

    for (0..header.e_phnum) |i| {
        const ph = ph_table[i];
        if (ph.p_type == std.elf.PT_LOAD) {
            if (ph.p_vaddr < min_vaddr) min_vaddr = ph.p_vaddr;
            const segment_end = ph.p_vaddr + ph.p_memsz;
            if (segment_end > max_vaddr) max_vaddr = segment_end;
        }
    }

    const total_kernel_size = max_vaddr - min_vaddr;

    const total_pages = (total_kernel_size + 4095) / 4096;
    const final_kernel_phys_ptr = try boot_services.allocatePages(.{ .max_address = @ptrFromInt(MAX_KERNEL_ALLOCATION) }, .loader_code, total_pages);
    const kernel_phys_base: usize = @intFromPtr(final_kernel_phys_ptr.ptr);

    for (0..header.e_phnum) |i| {
        const ph = ph_table[i];
        if (ph.p_type == std.elf.PT_LOAD) {
            const segment_phys_addr = kernel_phys_base + (ph.p_vaddr - min_vaddr);
            const segment_ptr: [*]u8 = @ptrFromInt(segment_phys_addr);

            const file_data_start = ph.p_offset;
            const file_data_end = ph.p_offset + ph.p_filesz;

            @memcpy(segment_ptr[0..ph.p_filesz], file_buffer[file_data_start..file_data_end]);
            if (ph.p_memsz > ph.p_filesz) {
                const bss_size = ph.p_memsz - ph.p_filesz;
                const bss_ptr = segment_ptr + ph.p_filesz;
                @memset(bss_ptr[0..bss_size], 0);
            }
        }
    }
    uefi_print("Kernel physical address: 0x{x}\n", .{kernel_phys_base});
    try map_kernel_vma(total_kernel_size, kernel_phys_base, min_vaddr);
    return .{
        .kernel_lma = kernel_phys_base,
        .kernel_vma = header.e_entry,
        .kernel_size = total_pages * 4096,
    };
}

fn load_page_directory(addr: usize) void {
    asm volatile ("mov %[addr], %%cr3"
        :
        : [addr] "r" (addr),
        : .{ .memory = true });
}

fn uefi_print(comptime format: []const u8, args: anytype) void {
    var utf8_buf: [512]u8 = undefined;
    const formatted_text = std.fmt.bufPrint(&utf8_buf, format, args) catch return;

    var utf16_buf: [512:0]u16 = undefined;
    var i: usize = 0;

    for (formatted_text) |char| {
        if (i >= utf16_buf.len - 1) break;

        if (char == '\n' and (i == 0 or utf16_buf[i - 1] != '\r')) {
            utf16_buf[i] = '\r';
            i += 1;
            if (i >= utf16_buf.len - 1) break;
        }
        utf16_buf[i] = char;
        i += 1;
    }
    utf16_buf[i] = 0;
    if (uefi.system_table.con_out) |con_out| {
        _ = con_out.outputString(utf16_buf[0..i :0].ptr) catch return;
    }
}

fn die(msg: []const u8) noreturn {
    uefi_print("\n[FATAL] {s}\n", .{msg});
    while (true) asm volatile ("cli; hlt");
}

pub fn main() uefi.Status {
    const boot_services = uefi.system_table.boot_services orelse return .device_error;
    uefi_print("UEFI Bootloader!\n", .{});
    uefi_print("Bootloader base hint: 0x{x}\n", .{@intFromPtr(&main)});
    uefi_print("Creating page directory!\n", .{});
    init_page_directory(boot_services) catch die("Failed to initialize page directory");
    uefi_print("Page directory located at 0x{x}\n", .{@intFromPtr(pml4_table)});
    paging.init(boot_services);

    const pages = boot_services.allocatePages(.any, .loader_code, 512) catch return .device_error;

    const fs = boot_services.locateProtocol(uefi.protocol.SimpleFileSystem, null) catch return .device_error;
    var root = fs.?.openVolume() catch return .device_error;

    var kernel_file = root.open(&[_:0]u16{ 'k', 'e', 'r', 'n', 'e', 'l', '.', 'e', 'l', 'f' }, .read, .{}) catch return .aborted;
    const buffer = std.mem.sliceAsBytes(pages);

    _ = kernel_file.read(buffer) catch return .device_error;
    kernel_file.close() catch return .device_error;
    root.close() catch return .device_error;
    uefi_print("Loading kernel elf...\n", .{});
    const kernel_memory_data = load_elf(buffer, boot_services) catch return .aborted;
    uefi_print("Kernel Physical Base: 0x{x}, Kernel Size: {d} bytes, Kernel Virtual Address: 0x{x}\n", .{ kernel_memory_data.kernel_lma, kernel_memory_data.kernel_size, kernel_memory_data.kernel_vma });
    // Searching RSDP
    var rsdp_address: u64 = 0;
    const acpi_20_guid = uefi.Guid{
        .time_low = 0x8868e871,
        .time_mid = 0xe4f1,
        .time_high_and_version = 0x11d3,
        .clock_seq_high_and_reserved = 0xbc,
        .clock_seq_low = 0x22,
        .node = [_]u8{ 0x00, 0x80, 0xc7, 0x3c, 0x88, 0x81 },
    };

    const config_tables = uefi.system_table.configuration_table;
    const num_tables = uefi.system_table.number_of_table_entries;

    for (config_tables[0..num_tables]) |table| {
        if (std.mem.eql(u8, std.mem.asBytes(&table.vendor_guid), std.mem.asBytes(&acpi_20_guid))) {
            rsdp_address = @intFromPtr(table.vendor_table);
            break;
        }
    }
    if (rsdp_address == 0) {
        uefi_print("ALERT: ACPI 2.0 Table not found! (rsdp_address = 0)\n", .{});
    }

    uefi_print("Loading memory map\n", .{});
    var map_buf_ptr = boot_services.allocatePool(.boot_services_data, 16384) catch return .aborted;
    const buf = map_buf_ptr[0..16384];
    uefi_print("Map Buffer allocated at 0x{x}\n", .{@intFromPtr(buf)});

    const pml4_addr = @intFromPtr(pml4_table);
    const buf_end = @intFromPtr(buf) + 16384;
    const kernel_end = kernel_memory_data.kernel_lma + kernel_memory_data.kernel_size;
    const temp_stack = boot_services.allocatePages(.{ .max_address = @ptrFromInt(paging.MAX_ALLOCATION_ADDR) }, .loader_data, 4) catch die("Failed to alloc temp stack!");
    const temp_stack_top = @intFromPtr(temp_stack.ptr) + (4 * 4096);
    const bootInfoAlloc = boot_services.allocatePool(.loader_data, @as(usize, @sizeOf(BootInfo))) catch @panic("Failed to alloc BootInfo Pool");

    const map_limit = @max(@max(pml4_addr, buf_end), @max(kernel_end, @intFromPtr(temp_stack.ptr))) + 0x1000;
    map_ram(map_limit) catch die("Failed to map RAM");

    const memory_map = boot_services.getMemoryMap(buf) catch {
        die("Failed to get UEFI Memory Map!\n");
        return .aborted;
    };

    _ = boot_services.exitBootServices(uefi.handle, memory_map.info.key) catch {
        return .aborted;
    };
    asm volatile ("cli");
    asm volatile (
        \\mov %[stack], %%rsp
        \\mov %[stack], %%rbp
        :
        : [stack] "r" (temp_stack_top),
    );
    load_page_directory(@intFromPtr(pml4_table));
    asm volatile ("sti");

    const entry: KernelEntryFn = @ptrFromInt(kernel_memory_data.kernel_vma);
    const info: *BootInfo = @ptrCast(@alignCast(bootInfoAlloc.ptr));
    info.* = BootInfo{
        .map = @ptrCast(@alignCast(memory_map.ptr)),
        .map_size = memory_map.info.len * memory_map.info.descriptor_size,
        .desc_size = memory_map.info.descriptor_size,
        .rsdp_addr = rsdp_address,
        .kernel_phys = kernel_memory_data.kernel_lma,
        .kernel_size = kernel_memory_data.kernel_size,
    };
    serial_print("Jump\n");
    entry(info);
}
