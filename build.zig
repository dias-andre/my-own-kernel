const std = @import("std");

const ModuleEntry = struct { name: []const u8, mod: *std.Build.Module };

fn createKernelModule(b: *std.Build, filename: []const u8) *std.Build.Module {
    var target_query = std.Target.Query{
        .cpu_arch = .x86_64,
        .os_tag = .freestanding,
    };

    const features = std.Target.x86.Feature;
    target_query.cpu_features_sub.addFeature(@intFromEnum(features.soft_float));
    const kernel_target = b.resolveTargetQuery(target_query);
    const kernel_optimize = std.builtin.OptimizeMode.ReleaseSafe;
    const module = b.createModule(.{
        .root_source_file = b.path(filename),
        .target = kernel_target,
        .optimize = kernel_optimize,
    });
    module.pic = false;
    module.stack_check = false;
    module.stack_protector = false;
    module.red_zone = false;
    module.code_model = .kernel;
    return module;
}

fn createObjectToKernel(b: *std.Build, module: *std.Build.Module, object_output: []const u8) *std.Build.Step.Compile {
    const object = b.addObject(.{
        .root_module = module,
        .name = object_output,
    });
    object.pie = false;
    return object;
}

pub fn build(b: *std.Build) void {
    const build_uefi = b.option(bool, "uefi", "Build UEFI bootloader?") orelse false;

    const kernel_module = createKernelModule(b, "kernel/main.zig");
    const bootinfo_module = b.createModule(.{
        .root_source_file = b.path("kernel/boot/bootinfo.zig"),
    });
    kernel_module.addAssemblyFile(b.path("kernel/arch/x86/smp/trampoline.s"));
    kernel_module.addImport("bootinfo", bootinfo_module);

    const libc_object = createObjectToKernel(b, createKernelModule(b, "kernel/utils/libc_stubs.zig"), "libc.o");
    kernel_module.addObject(libc_object);

    const module_list = [_]ModuleEntry{
        .{ .name = "arch", .mod = b.createModule(.{ .root_source_file = b.path("kernel/arch/x86/impl.zig") }) },
        .{ .name = "lib", .mod = b.createModule(.{ .root_source_file = b.path("kernel/lib/root.zig") }) },
        .{ .name = "kmem", .mod = b.createModule(.{ .root_source_file = b.path("kernel/mm/root.zig") }) },
        .{ .name = "klog", .mod = b.createModule(.{ .root_source_file = b.path("kernel/utils/klog.zig") }) },
        .{ .name = "smp", .mod = b.createModule(.{ .root_source_file = b.path("kernel/smp.zig") }) },
        .{ .name = "khal", .mod = b.createModule(.{ .root_source_file = b.path("kernel/hal/root.zig") }) },
        .{ .name = "ktimer", .mod = b.createModule(.{ .root_source_file = b.path("kernel/time/timer.zig") }) },
        .{ .name = "sched", .mod = b.createModule(.{ .root_source_file = b.path("kernel/sch/root.zig") }) },
        .{ .name = "proc", .mod = b.createModule(.{ .root_source_file = b.path("kernel/proc/root.zig") }) },
    };

    for (module_list) |target_mod| {
        for (module_list) |dependency_mod| {
            if (std.mem.eql(u8, target_mod.name, dependency_mod.name)) continue;
            target_mod.mod.addImport(dependency_mod.name, dependency_mod.mod);
        }
        kernel_module.addImport(target_mod.name, target_mod.mod);
        target_mod.mod.addImport("bootinfo", bootinfo_module);
    }

    // BOOT_MODULE
    if (build_uefi) {
        const uefi_target = b.resolveTargetQuery(.{
            .cpu_arch = .x86_64,
            .os_tag = .uefi,
        });

        const bootloader = b.addExecutable(.{
            .name = "BOOTX64",
            .root_module = b.createModule(.{
                .root_source_file = b.path("kernel/boot/start.zig"),
                .target = uefi_target,
                .optimize = b.standardOptimizeOption(.{}),
            }),
        });
        bootloader.root_module.addImport("bootinfo", bootinfo_module);
        b.installArtifact(bootloader);
        return;
    }

    // TARGET KERNEL FILE
    const kernel_elf = b.addExecutable(.{ .name = "kernel.elf", .root_module = kernel_module });
    kernel_elf.setLinkerScript(b.path("linker.ld"));
    kernel_elf.pie = false;
    b.installArtifact(kernel_elf);
}
