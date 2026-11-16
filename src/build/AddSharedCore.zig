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

    const embeddable_defaults = [_]struct {
        import_alias: []const u8,
        file_name: []const u8,
    }{
        .{
            .import_alias = "default_config",
            .file_name = "config.machtoo"
        },
        .{
            .import_alias = "command_schema",
            .file_name = "command.schema.toml",
        },

    };

    for (embeddable_defaults) |entry| {
        options.module.addAnonymousImport(entry.import_alias, .{
            .root_source_file = b.path(entry.file_name)
        });
    }
}

