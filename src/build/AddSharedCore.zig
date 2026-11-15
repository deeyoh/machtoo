/// Creates the core module. Central location for build steps that are
/// shared betwene both the GTK and library runtime.
/// Any shared functionality, such as
/// common dependencies, between the two build
/// systems will be defined here.
const AddSharedCore = @This();

const std = @import("std");

pub const Options = struct {
    module: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    optimize: std.lang.Optimize,
};

pub fn init(
    b: *std.Build,
    options: Options,
) void {
    const toml_dep = b.dependency("toml", .{
        .target = options.target,
        .optimize = options.optimize,
    });
    options.module.addImport("toml", toml_dep.module("toml"));

    options.module.addAnonymousImport("default_config", .{
        .root_source_file = b.path("config.machtoo")
    });
}

