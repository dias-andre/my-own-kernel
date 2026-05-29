const arch = @import("arch");
const ctx = arch.ctx;
const kmem = @import("kmem");
const ksmp = @import("smp");
const Thread = @import("proc").Thread;

// each core has its own RunQueue
pub const RunQueue = struct {
    idleThread: ?*Thread = null,
    currentThread: ?*Thread = null,
    threadCount: usize = 0,
};

pub fn push_thread(new_thread: *Thread) void {
    var current_thread = ksmp.get_current_core().runQueue.currentThread;
    if (current_thread) |curr| {
        new_thread.next = curr.next;
        curr.next = new_thread;
    } else {
        new_thread.next = new_thread;
        current_thread = new_thread;
    }
}

pub fn schedule(current_core: *ksmp.CpuCore) void {
    var current_thread = current_core.runQueue.currentThread;
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

            // const prev_proc = if (current_thread) |t| t.process else null;
            // const next_proc = next_thread.process;
            //
            // if (prev_proc != next_proc) {
            //     if (next_proc) |proc| {
            //         arch.paging.load_page_directory(proc.page_directory);
            //     } else {
            //         arch.paging.load_page_directory(kmem.kernel_pages());
            //     }
            // }

            current_thread = next_thread;
            next_thread.state = .Running;
            arch.ctx.switch_context(&prev.ctx.rsp, next_thread.ctx.rsp);
        }
    } else {
        current_core.runQueue.currentThread = current_core.runQueue.idleThread.?;
    }
}

pub fn get_current_thread() ?*Thread {
    return ksmp.get_current_core().runQueue.currentThread;
}
