const std = @import("std");
const MachtooLib = @import("build/MachtooLib.zig");
const LipoStep = @import("build/LipoStep.zig");
const XCFrameworkStep = @import("build/XCFrameworkStep.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("machtoo", .{
        // The root source file is the "entry point" of this module. Users of
        // this module will only be able to access public declarations contained
        // in this file, which means that if you have declarations that you
        // intend to expose to consumers that were defined in other files part
        // of this module, you will have to make sure to re-export them from
        // the root file.
        .root_source_file = b.path("src/root.zig"),
        // Later on we'll use this module as the root module of a test executable
        // which requires us to specify a target.
        .target = target,
    });

    const exe = b.addExecutable(.{
        .name = "machtoo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "machtoo", .module = mod },
            },
        }),
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.addPassthruArgs();

    // const mod_tests = b.addTest(.{
    //     .root_module = mod,
    // });
    //
    // const run_mod_tests = b.addRunArtifact(mod_tests);
    //
    // const exe_tests = b.addTest(.{
    //     .root_module = exe.root_module,
    // });
    // const run_exe_tests = b.addRunArtifact(exe_tests);
    // const test_step = b.step("test", "Run tests");
    // test_step.dependOn(&run_mod_tests.step);
    // test_step.dependOn(&run_exe_tests.step);

    //@NOTE: === STATIC LIBRARY ===
    const arm = MachtooLib.initStatic(b, .{
        .target = b.resolveTargetQuery(.{
            .cpu_arch = .aarch64,
            .os_tag = .macos,
        }),
        .optimize = optimize
    });

    const intel = MachtooLib.initStatic(b, .{
        .target = b.resolveTargetQuery(.{
            .cpu_arch = .x86_64,
            .os_tag = .macos,
        }),
        .optimize = optimize
    });

    const universal = LipoStep.create(b, .{
        .name = "machtoo",
        .out_name = "libmachtoo.a",
        .input_a = arm.lib.getEmittedBin(),
        .input_b = intel.lib.getEmittedBin(),
    });

    const install = b.addInstallFile(
        universal.output,
        "lib/libmachtoo.a",
    );

    b.getInstallStep().dependOn(&install.step);

    const xcframework = XCFrameworkStep.create(b, .{
        .name = "MachtooKit",
        .out_path = "macos/MachtooKit.xcframework",
        .library = universal.output,
        .headers = b.path("include"),
    });

    b.default_step.dependOn(xcframework.step);
}
