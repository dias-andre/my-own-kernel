pub const DriverType = enum { CHAR, BLOCK, NETWORK };

pub const Driver = struct {
  name: []const u8,
  type: DriverType,
  init_fn: *const fn() void,
  read_fn: *const fn() u8,
};