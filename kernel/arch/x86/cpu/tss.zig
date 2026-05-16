pub const TaskStateSegment = packed struct {
    reserved: u32 = 0,
    rsp0: u64 = 0,
    rsp1: u64 = 0,
    rsp2: u64 = 0,
    reserved2: u64 = 0,
    ist1: u64 = 0,
    ist2: u64 = 0,
    ist3: u64 = 0,
    ist4: u64 = 0,
    ist5: u64 = 0,
    ist6: u64 = 0,
    ist7: u64 = 0,
    reserved3: u64 = 0,
    reserved4: u16 = 0,
    iomap_base: u16 = 0
};

pub var tss: TaskStateSegment = .{};