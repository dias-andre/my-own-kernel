const cpu = @import("../arch/x86/cpu.zig");
const pic = @import("../arch/x86/pic.zig");
const log = @import("../utils/klog.zig").Logger;
const sch = @import("../sch/index.zig");

const BASE_FREQUENCY = 1193180;
const COMMAND_PORT = 0x43;
const DATA_PORT_0 = 0x40;

var ticks: u64 = 0;

pub fn init(freq: u32) void {
  const divisor = BASE_FREQUENCY / freq;
  cpu.outb(COMMAND_PORT, 0x36);

  const l = @as(u8, @truncate(divisor));
  const h = @as(u8, @truncate(divisor >> 8));
  
  cpu.outb(DATA_PORT_0, l);
  cpu.outb(DATA_PORT_0, h);
  log.ok("[PIT] Timer initialized!", .{});
}

pub fn handle_irq() void {
  ticks += 1;
  //vga.print(".");
  // pic.sendEOI(0);
  sch.schedule();
}

pub fn get_ticks() u64 {
  return ticks;
}