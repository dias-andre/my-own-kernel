pub const Process = struct {
    id: usize,
    name: []const u8,
    ref_count: usize,
    page_directory: usize,
    next: ?*Process
};

