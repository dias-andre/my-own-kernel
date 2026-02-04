pub const MemoryRegion = struct {
    base: usize,
    len: usize,
    type: enum { Free, Reserved, Kernel }
};

pub const MemoryMap = struct {
    regions: [64]MemoryRegion = undefined,
    count: usize = 0
};