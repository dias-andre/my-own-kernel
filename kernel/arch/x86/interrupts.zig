const pic = @import("pic.zig");
const cpu = @import("cpu.zig");

pub fn init() void{
    pic.remap();
    cpu.enable_interrupts();
}