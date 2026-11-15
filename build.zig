const std = @import("std");
const buildpkg = @import("src/build/buildpkg.zig");

const MachtooLib = buildpkg.MachtooLib;
const LipoStep = buildpkg.LipoStep;
const XCFrameworkStep = buildpkg.XCFrameworkStep;

pub fn build(b: *std.Build) void {
    // const target = b.standardTargetOptions(.{});
    // const optimize = b.standardOptimizeOption(.{});
    // const exe = b.addExecutable(.{
    //     .name = "machtoo",
    //     .root_module = b.createModule(.{
    //         .root_source_file = b.path("src/main.zig"),
    //         .target = target,
    //         .optimize = optimize,
    //         // .imports = &.{
    //         //     .{ .name = "machtoo", .module = mod },
    //         // },
    //     }),
    // });
    // b.installArtifact(exe);

    // const run_step = b.step("run", "Run the app");
    // const run_cmd = b.addRunArtifact(exe);
    // run_step.dependOn(&run_cmd.step);
    // run_cmd.step.dependOn(b.getInstallStep());
    // run_cmd.addPassthruArgs();

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

    const config = buildpkg.Config.init(b);
    // if Linux, need to create executable, otherwise, static library


    //@NOTE: === STATIC LIBRARY ===
    const shared_deps = [_][]const u8{
        "toml",
    };

    //need to add zig-gobject, but it is a Linux only dep.
    //The Linux GTK app does not use the static library.
    //It instead compiles the shared Zig core directly
    //into the executable and calls it from Zig (direct Zig)

    const arm = MachtooLib.initStatic(b, .{
        .target = b.resolveTargetQuery(.{
            .cpu_arch = .aarch64,
            .os_tag = .macos,
        }),
        .optimize = config.optimize,
        .shared_zig_deps = &shared_deps,
    });

    const intel = MachtooLib.initStatic(b, .{
        .target = b.resolveTargetQuery(.{
            .cpu_arch = .x86_64,
            .os_tag = .macos,
        }),
        .optimize = config.optimize,
        .shared_zig_deps = &shared_deps,
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
