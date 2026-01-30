pub const Thread = struct {
    rsp: usize,
    stack_base: usize,
    id: usize,
    next: ?*Thread,

    pub fn init(self: *Thread, entry_point: usize) void {
        const stack_top = self.stack_base + 4096;
        var ptr = @as([*]u64, @ptrFromInt(stack_top));

        ptr -= 1;
        ptr[0] = entry_point;

        ptr -= 1; ptr[0] = 0; // R15
        ptr -= 1; ptr[0] = 0; // R14
        ptr -= 1; ptr[0] = 0; // R13
        ptr -= 1; ptr[0] = 0; // R12
        ptr -= 1; ptr[0] = 0; // RBP
        ptr -= 1; ptr[0] = 0; // RBX
        self.rsp = @intFromPtr(ptr);
    }
};