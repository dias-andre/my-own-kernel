const kmem = @import("../mm/index.zig");
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

    kernel_process = Process.create(null,"kernel_main", kmem.kernel_pml4(), kmem.kernel_allocator()) catch |err| {
        log.failed("Failed to create kernel process. Error: {}", .{err});
        while (true) asm volatile ("hlt");
    };

    kernel_process.id = get_new_pid();

    spawn_kernel_thread(@intFromPtr(&idle_thread)) catch |err| {
        log.failed("Failed to create main thread. Error: {}", .{err});
        while (true) asm volatile ("hlt");
    };

    log.ok("Process Manager started successfully! ", .{});
    log.info("Kernel process started with PID: {}", .{kernel_process.id});
}

pub fn spawn(entry_point: usize, is_user: bool, name: []const u8) !usize {
    _ = is_user;
    const current_thread = sch.get_current_thread();
    const parent_proc = if (current_thread) |t| t.process.? else kernel_process;
    const pml4_phys = try kmem.create_pml4();

    const new_process = try Process.create(parent_proc, name, pml4_phys, kmem.kernel_allocator());
    new_process.id = get_new_pid();
    
    parent_proc.addChild(new_process);
    _ = try start_thread(new_process, entry_point);
    return new_process.id;
}

fn start_thread(owner: *Process, entry_point: usize) !*Thread {
    var new_thread: *Thread = try Thread.create(kmem.kernel_allocator());
    new_thread.id = get_new_tid();

    new_thread.process = owner;
    owner.addThread(new_thread);

    new_thread.state = .Ready;
    new_thread.init(entry_point);
    sch.push_thread(new_thread);
    return new_thread;
}

pub fn spawn_kernel_thread(entry_point: usize) !void {
    _ = try start_thread(kernel_process, entry_point);
}
