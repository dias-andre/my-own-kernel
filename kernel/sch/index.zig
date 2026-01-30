const log = @import("../utils/klog.zig").Logger;
const ctx = @import("context.zig");
const mem = @import("../mm/index.zig");
const Thread = @import("thread.zig").Thread;

const HHDM_OFFSET = 0xFFFF800000000000;

var current_thread: ?*Thread = null;
var current_id: usize = undefined;

fn main_thread() void {
    while (true) {}
}

pub fn create_thread(entry_point: usize) void {
    var new_thread: *Thread = mem.create(Thread) catch {
        log.failed("Failed to allocate memory for thread creation", .{});
        return;
    };

    const phys_stack = mem.pmm.allocate_page() catch {
        log.failed("No physicial pages during thread creation!", .{});
        return;
    };

    const stack_base = phys_stack + HHDM_OFFSET;

    mem.vmm.map_page(mem.vmm.kernel_pml4, stack_base, phys_stack, mem.vmm.PAGE_PRESENT | mem.vmm.PAGE_RW) catch {
        const ptr1: *u64 = @ptrFromInt(phys_stack);
        const ptr2: *u64 = @ptrFromInt(stack_base);
        log.failed("Failed to map address {} to virtual address {} during thread creation.", .{ ptr1, ptr2 });
        return;
    };

    new_thread.stack_base = stack_base;
    new_thread.id = current_id;
    current_id += 1;
    new_thread.init(entry_point);

    if (current_thread) |curr| {
        new_thread.next = curr.next;
        curr.next = new_thread;
    } else {
        new_thread.next = new_thread;
        current_thread = new_thread;
    }
}

pub fn init() void {
    log.info("Starting multithreading", .{});
    current_id = 0;
    create_thread(@intFromPtr(&main_thread));
    log.ok("Multithreading enabled! Main thread started. ", .{});
}

pub fn schedule() void {
    if (current_thread) |prev| {
        var next = prev.next;

        if (next == null) next = prev;

        if (next == prev) return;

        current_thread = next;

        ctx.switch_context(&prev.rsp, next.?.rsp);
    }
}
