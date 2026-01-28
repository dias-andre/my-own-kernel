const cpu = @import("../arch/x86/cpu.zig");
const vga = @import("../vga.zig");

const KBD_DATA_PORT = 0x60;

const scancode_map = [_]u8{
    0, 0, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', 0, // 0x00-0x0E
    '\t', 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', '\n', // 0x0F-0x1C
    0, 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', '\'', '`', // 0x1D-0x29
    0, '\\', 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0, // 0x2A-0x36
    '*', 0, ' ', 0, // 0x37-0x3A
};

pub fn handle_irq() void {
  const scancode = cpu.inb(KBD_DATA_PORT);
  if(scancode < 0x80) {
    if(scancode < scancode_map.len) {
      const char = scancode_map[scancode];
      const arr = [_]u8{char};
      if(char != 0) {
        vga.print(&arr);
      }
    }
  }
}