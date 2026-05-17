const std = @import("std");

pub const KernelBuildOption = enum { Binary, Object };
const ModuleEntry = struct { name: []const u8, mod: *std.Build.Module };

pub fn build(b: *std.Build) void {
    const target_kernel_option = b.option(KernelBuildOption, "kbuild", "Select the target Kernel build") orelse .Object;
    const build_uefi = b.option(bool, "uefi", "Build UEFI bootloader?") orelse false;

    // KERNEL_MODULE
    var target_query = std.Target.Query{
        .cpu_arch = .x86_64,
        .os_tag = .freestanding,
    };
    const features = std.Target.x86.Feature;
    target_query.cpu_features_sub.addFeature(@intFromEnum(features.soft_float));
    const kernel_target = b.resolveTargetQuery(target_query);
    const kernel_optimize = std.builtin.OptimizeMode.ReleaseSafe;
    const kernel_module = b.createModule(.{
        .root_source_file = b.path("kernel/main.zig"),
        .target = kernel_target,
        .optimize = kernel_optimize,
    });
    kernel_module.pic = false;

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
        kernel_module.addImport(target_mod.name, target_mod.mod);
    }

    kernel_module.stack_check = false;
    kernel_module.stack_protector = false;

    // BOOT_MODULE
    if (build_uefi) {
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
    }

    // TARGET KERNEL FILE
    switch (target_kernel_option) {
        .Binary => {
            const kernel_elf = b.addExecutable(.{ .name = "kernel.elf", .root_module = kernel_module });
            kernel_elf.setLinkerScript(b.path("kernel.ld"));
            kernel_elf.pie = false;
            const kernel_bin = kernel_elf.addObjCopy(.{ .format = .bin });
            const install_bin = b.addInstallFile(kernel_bin.getOutput(), "bin/kernel.bin");
            b.getInstallStep().dependOn(&install_bin.step);
            b.installArtifact(kernel_elf);
        },
        .Object => {
            const kernel_object = b.addObject(.{
                .name = "kernel.o",
                .root_module = kernel_module,
            });
            const install_step = b.addInstallFile(kernel_object.getEmittedBin(), "bin/kernel.o");
            b.getInstallStep().dependOn(&install_step.step);
        },
    }
}
