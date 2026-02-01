const klog = @import("utils/klog.zig");
const mb = @import("multiboot.zig");
const mm = @import("mm/index.zig");
const gdt = @import("arch/x86/gdt.zig");
const idt = @import("arch/x86/idt.zig");
const pic = @import("arch/x86/pic.zig");
const cpu = @import("arch/x86/cpu.zig");
const pit = @import("drivers/pit.zig");
const stubs = @import("utils/libc_stubs.zig");
const proc = @import("proc/manager.zig");

const vmm = @import("mm/vmm.zig");
const log = @import("utils/klog.zig").Logger;

const sys_exit = @import("sys/sys_exit.zig").sys_exit;

const sys = @import("sys/entry.zig");

extern var _start: u8;
extern var _end: u8;

fn thread_b() void {
    log.info("Thread B started!", .{});
    log.println("- Thread B exited with code 0", .{});
    sys_exit(0);
    while(true) {
        var i: usize = 0;
        while(i < 10000):(i += 1) {
            log.println("b", .{});
        }
    }
}

fn thread_a() void {
    log.info("Starting Thread A", .{});
    while(true) asm volatile("hlt");
}

export fn kernel_main(pointer: u64, magic: u64) callconv(.c) noreturn {
    _ = stubs;
    log.info("The execution reached kernel main", .{});
    // get multiboot info
    const mb_info = mb.init(pointer, magic);
    const kernel_end_addr = @intFromPtr(&_end);

    // starts memory management subsystem
    mm.init(mb_info, kernel_end_addr);
    gdt.init();
    idt.init();

    map_video_address();
    proc.init();
    pic.remap();
    pit.init(100);

    log.info("Enabling Interrupts...", .{});
    cpu.sti();
    log.ok("Interrupts enabled! ", .{});

    log.info("Enabling System calls...", .{});
    const syscall_entry: u64 = @intFromPtr(&sys.syscall_entry);
    cpu.enable_syscalls(syscall_entry);
    log.ok("System calls enabled! ", .{});

    log.info("Creating kernel threads", .{});
    proc.spawn_kernel_thread(@intFromPtr(&thread_a)) catch {
        log.failed("Error to start thread_a", .{});
        while(true) asm volatile("hlt");
    };
    proc.spawn_kernel_thread(@intFromPtr(&thread_b)) catch {
        log.failed("Error to start thread_b", .{});
        while(true) asm volatile("hlt");
    };
    while (true) cpu.halt();
}

fn map_video_address() void {
    const vga_physical = 0xb8000;
    const vga_virtual = 0xC0000000 + 0xb8000;
    log.info("Mapping VGA to a virtual address", .{});
    vmm.map_page(vmm.kernel_pml4, vga_virtual, vga_physical, vmm.PAGE_PRESENT | mm.vmm.PAGE_RW) catch {
        log.failed("Failed to map physical address {} to virtual address {}", .{vga_physical, vga_virtual});
        while(true) asm volatile("hlt");
    };
    klog.screen.video_address = vga_virtual;
    const address: *u64 = @ptrFromInt(vga_virtual);
    log.ok("VGA mapped to {}", .{address});
}

fn testFaultHandler() void {
    const bad_ptr: *u64 = @ptrFromInt(0xB0000000);
    bad_ptr.* = 0xDEADBEEF;
}
