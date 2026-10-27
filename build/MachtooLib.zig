const MachtooLib = @This();
const std = @import("std");

lib: *std.Build.Step.Compile,

pub const Options = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
};

pub fn initStatic(
    b: *std.Build,
    options: Options
) MachtooLib {
    const lib = b.addLibrary(.{
        .name = "machtoo",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/api.zig"),
            .target = options.target,
            .optimize = options.optimize,
        })
    });

    return .{ .lib = lib };
}
