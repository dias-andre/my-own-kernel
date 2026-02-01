const ctx = @import("context.zig");
const kmem = @import("../mm/index.zig");
const Thread = @import("thread.zig").Thread;
const pit = @import("../drivers/pit.zig");

var current_thread: ?*Thread = null;

pub fn push_thread(new_thread: *Thread) void {
    if (current_thread) |curr| {
        new_thread.next = curr.next;
        curr.next = new_thread;
    } else {
        new_thread.next = new_thread;
        current_thread = new_thread;
    }
}

pub fn schedule() void {
    if (current_thread) |prev| {
        if (prev.state == .Running) {
            prev.state = .Ready;
        }

        var next = prev.next;

        while (next != null) {
            if (next.?.state == .Ready) {
                break;
            }

            if (next == prev) {
                if (prev.state != .Ready) {
                    return;
                }
                break;
            }

            next = next.?.next;
        }

        if (next) |next_thread| {
            if (next_thread == prev) {
                next_thread.state = .Running;
                return;
            }

            const prev_proc = if (current_thread) |t| t.process else null;
            const next_proc = next_thread.process;

            if (prev_proc != next_proc) {
                if (next_proc) |proc| {
                    write_cr3(proc.page_directory);
                } else {
                    write_cr3(kmem.kernel_pml4());
                }
            }

            current_thread = next_thread;
            next_thread.state = .Running;
            ctx.switch_context(&prev.rsp, next_thread.rsp);
        }
    }
}

pub fn get_current_thread() ?*Thread {
    return current_thread;
}

fn write_cr3(pml4_phys: usize) void {
    asm volatile ("mov %[val], %%cr3"
        :
        : [val] "r" (pml4_phys),
        : .{ .memory = true }
    );
}
