const manager = @import("./root.zig");
const mem = @import("kmem");
const sch = @import("../sch/index.zig");
const std = @import("std");

const Thread = @import("thread.zig").Thread;

pub const Process = struct {
    id: usize,
    name: []const u8,
    ref_count: usize,
    page_directory: usize,

    parent: ?*Process,
    child_list_head: ?*Process,
    next_sibling: ?*Process,

    thread_list_head: ?*Thread,

    pub fn addThread(self: *Process, new_thread: *Thread) void {
        new_thread.next_sibling = self.thread_list_head;
        self.thread_list_head = new_thread;
        self.ref_count += 1;
    }

    pub fn iterateThreads(self: *Process) ThreadIterator {
        return ThreadIterator{ .current = self.thread_list_head };
    }

    pub fn iterateChildren(self: *Process) ProcessIterator {
        return ProcessIterator{ .current = self.child_list_head };
    }

    pub fn removeThread(self: *Process, target: *Thread) bool {
        const head = self.thread_list_head orelse return false;

        if (head == target) {
            self.thread_list_head = head.next_sibling;
            self.ref_count -= 1;
            return true;
        }

        var current = head;
        while (current.next_sibling) |next| {
            if (next == target) {
                current.next_sibling = next.next_sibling;
                self.ref_count -= 1;
                return true;
            }
            current = next;
        }
        return false;
    }

    pub fn addChild(self: *Process, new_proc: *Process) void {
        new_proc.next_sibling = self.child_list_head;
        self.child_list_head = new_proc;
    }

    pub fn removeChild(self: *Process, target: *Process) bool {
        const head = self.child_list_head orelse return false;

        if (head == target) {
            self.thread_list_head = head.next_sibling;
            self.ref_count = @atomicRmw(usize, &self.ref_count, .Sub, 1, .monotonic);
            return true;
        }

        var current = head;
        while (current.next_sibling) |next| {
            if (next == target) {
                current.next_sibling = next.next_sibling;
                self.ref_count = @atomicRmw(usize, &self.ref_count, .Sub, 1, .monotonic);
                return true;
            }
            current = next;
        }
        return false;
    }

    pub fn create(parent: ?*Process, name: []const u8, pml4_phys: usize, allocator: std.mem.Allocator) !*Process {
        const proc = try allocator.create(Process);
        const bytes = std.mem.asBytes(proc);
        @memset(bytes, 0);

        proc.parent = parent;
        proc.name = name;
        proc.page_directory = pml4_phys;
        proc.ref_count = 1;
        return proc;
    }

    pub const ThreadIterator = struct {
        current: ?*Thread,

        pub fn next(self: *ThreadIterator) ?*Thread {
            const curr = self.current;
            if (curr) |t| {
                self.current = t.next_sibling;
                return t;
            }
            return null;
        }
    };

    pub const ProcessIterator = struct {
        current: ?*Process,
        pub fn next(self: *ProcessIterator) ?*Process {
            const curr = self.current;
            if (curr) |p| {
                self.current = p.next_sibling;
                return p;
            }
            return null;
        }
    };
};

// TODO: fork
