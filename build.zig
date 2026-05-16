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
    const kernel = b.addExecutable(.{
        .name = "kernel.elf",
        .root_module = b.createModule(.{ .root_source_file = b.path("kernel/main.zig"), .target = target, .optimize = optimize }),
    });
    // kernel.setLinkerScript(b.path("linker.ld"));

    kernel.root_module.addObjectFile(b.path("build/starter.o"));
    kernel.root_module.addObjectFile(b.path("build/multiboot_header.o"));

    b.installArtifact(kernel);
}
