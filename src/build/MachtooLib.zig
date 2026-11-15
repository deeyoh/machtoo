const MachtooLib = @This();
const std = @import("std");

lib: *std.Build.Step.Compile,

pub const Options = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    shared_zig_deps: []const []const u8,
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
            .link_libc = true,
        })
    });

    for (options.shared_zig_deps) |name| {
        const dep = b.dependency(name, .{
            .target = options.target,
            .optimize = options.optimize,
        });
        lib.root_module.addImport(name, dep.module(name));
    }


    return .{ .lib = lib };
}
