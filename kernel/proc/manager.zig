const mem = @import("../mm/index.zig");
const log = @import("../utils/klog.zig").Logger;
const sch = @import("../sch/index.zig");

pub const Process = @import("process.zig").Process;
const Thread = @import("../sch/thread.zig").Thread;

var kernel_process: *Process = undefined;
var next_pid: usize = undefined;
var next_tid: usize = undefined;

fn idle_thread() void {
    while(true) {
        asm volatile("hlt");
    }
}

pub fn get_kernel_process() *Process { return kernel_process; }
pub fn get_new_pid() usize { return @atomicRmw(usize, &next_pid, .Add, 1, .monotonic); }
pub fn get_new_tid() usize { return @atomicRmw(usize, &next_tid, .Add, 1, .monotonic); }

pub fn init() void {
    log.info("Starting Process Manager...", .{});
    next_pid = 0;
    next_pid = 0;
    kernel_process = create_process("kernel_main", mem.kernel_page_directory) catch {
        log.failed("Failed to create kernel process.", .{});
        while (true) asm volatile ("hlt");
    };
    const main_thread = prepare_thread(kernel_process, @intFromPtr(&idle_thread)) catch {
        log.failed("Failed to create main thread.", .{});
        while (true) asm volatile ("hlt");
    };
    sch.push_thread(main_thread);
    log.ok("Process Manager started successfully! ", .{});
    log.info("Kernel process started with PID: {}", .{kernel_process.id});
}

pub fn create_process(name: []const u8, page_directory: usize) !*Process {
    log.info("Creating process: {} ", .{name});
    const process = try mem.create(Process);
    //log.ok("Memory allocated for {}, address: {}", .{ name, process });
    process.id = get_new_pid();
    // current_pid += 1;
    process.name = name;
    process.page_directory = page_directory;
    process.ref_count = 1;

    return process;
}

fn prepare_thread(owner: *Process, entry_point: usize) !*Thread {
    var new_thread: *Thread = try mem.create(Thread);

    const phys_stack = try mem.alloc_physical_page();
    const stack_base = mem.phys_to_virt(phys_stack);

    //mem.vmm.map_page(mem.vmm.kernel_pml4, stack_base, phys_stack, mem.vmm.PAGE_PRESENT | mem.vmm.PAGE_RW);
    // try mem.map_addr(owner.page_directory, stack_base, phys_stack, mem.vmm.PAGE_PRESENT | mem.vmm.PAGE_RW);
    new_thread.stack_base = stack_base;
    new_thread.id = get_new_tid();

    new_thread.process = owner;
    owner.addThread(new_thread);

    new_thread.state = .Ready;
    new_thread.init(entry_point);
    return new_thread;
}

pub fn destroy_thread(thread: *Thread) !void {
    if (thread.state != .Zombie) return error.ThreadNotZombie;

    var proc = thread.process orelse return error.NoOwnerProcess;

    const removed = proc.removeThread(thread);
    if(removed == false) {
        return error.ThreadNotRemoved;
    }
    
    const stack_phys = mem.virt_to_phys(thread.stack_base);
    mem.free_physical_page(stack_phys);
    // if(thread.process) |owner| {
    //     owner.ref_count -= 1;
    //     if(owner.ref_count == 0) {
    //         const process_ptr: [*]u8 = @ptrCast(owner);
    //         try mem.kfree(process_ptr);
    //     }
    // }
    const thread_ptr: [*]u8 = @ptrCast(thread);
    try mem.kfree(thread_ptr);
}

pub fn spawn_kernel_thread(entry_point: usize) !void {
    const thread = try prepare_thread(kernel_process, entry_point);
    sch.push_thread(thread);
}
