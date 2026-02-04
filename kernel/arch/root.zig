const builtin = @import("builtin");

pub const memory_map = @import("memory_map.zig");

const impl = switch (builtin.cpu.arch) {
    .x86_64 => @import("x86/impl.zig"),
    else => @compileError("Arquitetura não suportada!"),
};

pub const cpu = impl.cpu;
pub const paging = impl.paging;
pub const memory = impl.memory;
pub const boot = impl.boot;

// comptime {
//     const missing_error = "Architecture missing: ";

//     if (!@hasDecl(impl, "switch_context")) {
//         @compileError(missing_error ++ "switch_context(prev: *usize, next: usize) void");
//     }

//     if (!@hasDecl(impl, "init_user_mode")) {
//         @compileError(missing_error ++ "init_user_mode(...)");
//     }
// }