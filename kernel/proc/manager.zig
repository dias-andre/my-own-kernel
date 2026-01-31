const mem = @import("../mm/index.zig");
const log = @import("../utils/klog.zig").Logger;
const sch = @import("../sch/index.zig");

pub const Process = @import("process.zig").Process;
const Thread = @import("../sch/thread.zig").Thread;

const HHDM_OFFSET = 0xFFFF800000000000;

pub var kernel_process: *Process = undefined;
pub var current_pid: usize = undefined;
pub var current_tid: usize = undefined;

fn main_code() void {
    while(true) {}
}

pub fn create_process(name: []const u8, page_directory: usize) !*Process {
    log.info("Creating process: {} ", .{name});
    const process = try mem.create(Process);
    //log.ok("Memory allocated for {}, address: {}", .{ name, process });
    process.id = current_pid;
    current_pid += 1;
    process.name = name;
    process.page_directory = page_directory;
    process.ref_count = 0;
    process.next = null;

    return process;
}

fn prepare_thread(owner: *Process, entry_point: usize) !*Thread {
    var new_thread: *Thread = try mem.create(Thread);

    const phys_stack = try mem.alloc_physical_page();
    const stack_base = phys_stack + HHDM_OFFSET;

    //mem.vmm.map_page(mem.vmm.kernel_pml4, stack_base, phys_stack, mem.vmm.PAGE_PRESENT | mem.vmm.PAGE_RW);
    try mem.map_addr(owner.page_directory, stack_base, phys_stack, mem.vmm.PAGE_PRESENT | mem.vmm.PAGE_RW);
    new_thread.stack_base = stack_base;
    new_thread.id = current_tid;
    current_tid += 1;

    new_thread.process = owner;
    owner.ref_count += 1;

    new_thread.state = .Ready;
    new_thread.init(entry_point);
    return new_thread;
}

pub fn init() void {
    log.info("Starting Process Manager.", .{});
    current_pid = 0;
    current_tid = 0;
    kernel_process = create_process("kernel_main", mem.kernel_page_directory) catch {
        log.failed("Failed to create kernel process.", .{});
        while(true) asm volatile("hlt");
    };
    const main_thread = prepare_thread(kernel_process, @intFromPtr(&main_code)) catch {
        log.failed("Failed to create main thread.", .{});
        while(true) asm volatile("hlt");
    };
    sch.push_thread(main_thread);
    log.ok("Process Manager started successfulyy! ", .{});
}

pub fn destroy_thread(thread: *Thread) void {
    mem.free_physical_page(thread.stack_base);
    if(thread.process) |owner| {
        owner.ref_count -= 1;
        if(owner.ref_count == 0) {
            const process_ptr: [*]u8 = @ptrCast(owner);
            try mem.kfree(process_ptr);
        }
    }
    const thread_ptr: [*]u8 = @ptrCast(thread);
    try mem.kfree(thread_ptr);
}

pub fn start_thread(process: ?*Process, entry_point: usize) !void {
    var owner: *Process = undefined;
    if(process) |p| {
        owner = p;
    } else {
        owner = kernel_process;
    }
    const new_thread = try prepare_thread(owner, entry_point);
    sch.push_thread(new_thread);
}
