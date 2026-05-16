pub const InterruptController = struct {
    init: fn() void,
    enable_irq: fn(irq_number: u32) void,
    disable_irq: fn(irq_number: u32) void,
    ack_irq: fn(irq_number: u32) void
};