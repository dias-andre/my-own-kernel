const std = @import("std");

pub fn build(b: *std.Build) void {
    const uefi_target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .uefi,
    });

    const bootloader = b.addExecutable(.{
        .name = "BOOTX64",
        .root_module = b.createModule(.{
            .root_source_file = b.path("boot/start.zig"),
            .target = uefi_target,
            .optimize = b.standardOptimizeOption(.{}),
        }),
    });
    b.installArtifact(bootloader);

    var query = std.Target.Query{
        .cpu_arch = .x86_64,
        .os_tag = .freestanding,
    };
    const features = std.Target.x86.Feature;
    query.cpu_features_sub.addFeature(@intFromEnum(features.soft_float));

    const target = b.resolveTargetQuery(query);

    const optimize = std.builtin.OptimizeMode.ReleaseSafe;
    const kernel_obj = b.addObject(.{
        .name = "kernel.o",
        .root_module = b.createModule(.{ .root_source_file = b.path("kernel/main.zig"), .target = target, .optimize = optimize }),
    });

    const ModuleEntry = struct { name: []const u8, mod: *std.Build.Module };

    const module_list = [_]ModuleEntry{
        .{ .name = "arch", .mod = b.createModule(.{ .root_source_file = b.path("kernel/arch/root.zig") }) },
        .{ .name = "lib", .mod = b.createModule(.{ .root_source_file = b.path("kernel/lib/root.zig") }) },
        .{ .name = "kmem", .mod = b.createModule(.{ .root_source_file = b.path("kernel/mm/root.zig") }) },
        .{ .name = "klog", .mod = b.createModule(.{ .root_source_file = b.path("kernel/utils/klog.zig") }) },
    };

    for (module_list) |target_mod| {
        for (module_list) |dependency_mod| {
            if (std.mem.eql(u8, target_mod.name, dependency_mod.name)) continue;
            target_mod.mod.addImport(dependency_mod.name, dependency_mod.mod);
        }
        kernel_obj.root_module.addImport(target_mod.name, target_mod.mod);
    }

    kernel_obj.root_module.stack_check = false;
    kernel_obj.root_module.stack_protector = false;

    const install_step = b.addInstallFile(kernel_obj.getEmittedBin(), "bin/kernel.o");
    b.getInstallStep().dependOn(&install_step.step);
}
