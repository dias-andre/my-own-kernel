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
pub const interrupts = impl.interrupts;
pub const timer = impl.timer;

comptime {
    const missing_error = "Architecture missing:";

    if (!@hasDecl(cpu, "idle")) {
        @compileError(missing_error ++ "cpu.idle() void");
    }

    if (!@hasDecl(cpu, "enable_interrupts")) {
        @compileError(missing_error ++ "cpu.enable_interrupts() void");
    }

    if (!@hasDecl(cpu, "disable_interrupts")) {
        @compileError(missing_error ++ "cpu.disable_interrupts() void");
    }

    if (!@hasDecl(cpu, "enable_syscalls")) {
        @compileError(missing_error ++ "cpu.enable_syscalls() void");
    }

    // interrupts
    if (!@hasDecl(interrupts, "init")) {
        @compileError(missing_error ++ "interrupts.init() void");
    }

    //timer

    if (!@hasDecl(timer, "init")) {
        @compileError(missing_error ++ "timer.init(freq: u32) void");
    }
}


