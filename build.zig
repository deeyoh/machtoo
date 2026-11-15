const std = @import("std");
const buildpkg = @import("src/build/buildpkg.zig");

const MachtooLib = buildpkg.MachtooLib;
const LipoStep = buildpkg.LipoStep;
const XCFrameworkStep = buildpkg.XCFrameworkStep;

pub fn build(b: *std.Build) void {
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

    const shared_zig_deps = [_][]const u8{"toml"};

    switch (config.app_runtime) {
        .gtk => {
            std.debug.print("config app runtime determined: {}\n", .{config.app_runtime});
            const exe = b.addExecutable(.{
                .name = "machtoo",
                .root_module = b.createModule(.{
                    .root_source_file = b.path("src/main.zig"),
                    .target = config.target,
                    .optimize = config.optimize,
                }),
            });

            b.installArtifact(exe);

            const run_step = b.step("run", "Run the GTK app");
            const run_cmd = b.addRunArtifact(exe);
            run_step.dependOn(&run_cmd.step);
            run_cmd.step.dependOn(b.getInstallStep());
            run_cmd.addPassthruArgs();
        },
        .none => {
            //@NOTE: === STATIC LIBRARY ===
            std.debug.print("config app runtime determined: {}\n", .{config.app_runtime});
            const arm = MachtooLib.initStatic(b, .{
                .target = b.resolveTargetQuery(.{
                    .cpu_arch = .aarch64,
                    .os_tag = .macos,
                }),
                .optimize = config.optimize,
                .shared_zig_deps = &shared_zig_deps,
            });

            const intel = MachtooLib.initStatic(b, .{
                .target = b.resolveTargetQuery(.{
                    .cpu_arch = .x86_64,
                    .os_tag = .macos,
                }),
                .optimize = config.optimize,
                .shared_zig_deps = &shared_zig_deps,
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
        },
    }
}
