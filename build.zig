const std = @import("std");

pub fn build(b: *std.Build) void {
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

    const arch_module = b.createModule(.{ .root_source_file = b.path("kernel/arch/root.zig") });
    const lib_module = b.createModule(.{ .root_source_file = b.path("kernel/lib/root.zig") });

    kernel_obj.root_module.stack_check = false;
    kernel_obj.root_module.stack_protector = false;
    kernel_obj.root_module.addImport("arch", arch_module);
    kernel_obj.root_module.addImport("lib", lib_module);

    const install_step = b.addInstallFile(kernel_obj.getEmittedBin(), "bin/kernel.o");
    b.getInstallStep().dependOn(&install_step.step);
}
