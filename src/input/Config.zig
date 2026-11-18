const Config = @This();

const std = @import("std");
const Logger = @import("../Logger.zig");
const file_load = @import("file_load.zig");
const inputpkg = @import("../inputpkg.zig");

bindings: inputpkg.Binding.Tree = .{},

pub fn load(
    self: *Config,
    io: std.Io,
    alloc: std.mem.Allocator,
    environ_map: *std.process.Environ.Map,
) !void {
    _ = self;
    const config_path = try configPath(alloc, environ_map);
    Logger.logAt(
        .info,
        .config,
        @src(),
        "config path: {s}",
        .{config_path},
    );
    defer alloc.free(config_path);

    const file = std.Io.Dir.cwd().openFile(io, config_path, .{}) catch |err| switch (err) {
        error.FileNotFound => blk: {
            Logger.logAt(
                .info,
                .config,
                @src(),
                "config not found; creating default: {s}",
                .{config_path},
            );
            const cwd = std.Io.Dir.cwd();

            if (std.Io.Dir.path.dirname(config_path)) |parent| {
                try cwd.createDirPath(io, parent);
            }

            const created = try cwd.createFile(io, config_path, .{
                .read = true,
                .exclusive = true,
            });
            errdefer created.close(io);

            var buffer: [4096]u8 = undefined;
            var writer = created.writerStreaming(io, &buffer);

            try writer.interface.writeAll(inputpkg.default_config);
            try writer.interface.flush();

            break :blk created;
        },
        else => return err,
    };
    defer file.close(io);
}

fn configPath(
    alloc: std.mem.Allocator,
    environ_map: *std.process.Environ.Map
) ![]const u8 {
    const config_parent_dir = try file_load.defaultConfigHome(alloc, environ_map);
    defer alloc.free(config_parent_dir);

    return std.Io.Dir.path.join(alloc, &.{ config_parent_dir, "config.machtoo" });
}
