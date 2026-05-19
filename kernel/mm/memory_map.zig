pub const MemoryKind = enum { Free, Reserved, Kernel, BadMemory };

pub const MemoryRegion = struct {
    base: usize,
    len: usize,
    page_count: usize,
    type: MemoryKind,
};

pub const MemoryMap = struct { regions: [512]MemoryRegion = undefined, count: usize = 0 };
