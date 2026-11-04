const std = @import("std");
const arch = @import("arch");
const kmem = @import("kmem");
const log = @import("klog");
const sched = @import("sched");

pub const Process = @import("process.zig").Process;
pub const Thread = @import("thread.zig").Thread;

var name_buffer: [16]u8 = undefined;
var kernel_process: *Process = undefined;
var next_pid: usize = undefined;
var next_tid: usize = undefined;

fn idleThreadFunc() void {
    while (true) arch.cpu.idle();
}

pub fn get_kernel_process() *Process {
    return kernel_process;
}
pub fn get_new_pid() usize {
    return @atomicRmw(usize, &next_pid, .Add, 1, .monotonic);
}
pub fn get_new_tid() usize {
    return @atomicRmw(usize, &next_tid, .Add, 1, .monotonic);
}

pub fn init() void {
    log.info("Starting Process Manager...", .{});
    next_pid = 0;
    next_pid = 0;

    kernel_process = Process.create("kernel", kmem.kernel_pages(), null, kmem.kernel_allocator()) catch |err| {
        log.failed("Failed to create kernel process. Error: {any}", .{err});
        while (true) arch.cpu.idle();
    };

    kernel_process.id = get_new_pid();

    log.ok("Process Manager started successfully! ", .{});
    log.info("Kernel process started with PID: {d}", .{kernel_process.id});
}

pub fn prepareCoreRunQueue(coreId: usize, queue: *sched.RunQueue) void {
    if (@intFromPtr(kernel_process) == 0) @panic("Process manager not initialized while preparing core RunQueue");
    const processName = std.fmt.bufPrint(&name_buffer, "idle_inject/{d}", .{coreId}) catch @panic("Process name too long!");
    var process: *Process = Process.create(processName, kernel_process.page_directory, kernel_process, kmem.kernel_allocator()) catch @panic("Failed to create process while preparing RunQueue");
    process.id = get_new_pid();
    var idle_thread: *Thread = Thread.create(kmem.kernel_allocator()) catch @panic("Failed to create Thread while preparing RunQueue");
    idle_thread.id = get_new_tid();
    idle_thread.process = process;
    idle_thread.state = .Ready;
    idle_thread.init(@intFromPtr(&idleThreadFunc)) catch @panic("Failed to initialize Thread while preparing RunQueue");
    process.addThread(idle_thread);
    kernel_process.addChild(process);
    queue.idleThread = idle_thread;
    queue.threadCount += 1;
}
