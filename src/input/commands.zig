
const std = @import("std");
const toml = @import("toml");
const Command = @import("../corepkg.zig").Command;
const Logger = @import("../Logger.zig");
const file_load = @import("file_load.zig");
const inputpkg = @import("../inputpkg.zig");

pub const Storage = struct {
    const Map = std.array_hash_map.String(Command);

    commands: Map = .{},

    pub fn deinit(self: *Storage, alloc: std.mem.Allocator) void {
        self.commands.deinit(alloc);
        self.* = .{};
    }

    /// Reads defined command files and inserts them into the
    /// storage's array hash map, using its `id` as the key. If
    /// a `commands.toml` file does not exist, it creates one
    /// and adds an example command to demonstrate acceptable schema.
    pub fn load(
        self: *Storage,
        io: std.Io,
        alloc: std.mem.Allocator,
        environ_map: *std.process.Environ.Map,
    ) !void {
        _ = self;
        //owns its own TOML parser. This is not needed anywhere else
        //other than the load section
        var parser = toml.Parser(Command).init(alloc);
        defer parser.deinit();

        const commands_path = try commandsPath(alloc, environ_map);
        defer alloc.free(commands_path);

        Logger.logAt(
            .info,
            .commands,
            @src(),
            "commands path: {s}",
            .{commands_path},
        );

        const file = std.Io.Dir.cwd().openFile(io, commands_path, .{}) catch |err| switch (err) {
            error.FileNotFound => blk: {
                Logger.logAt(
                    .info,
                    .commands,
                    @src(),
                    "commands not found; creating default: {s}",
                    .{commands_path},
                );
                const cwd = std.Io.Dir.cwd();

                if (std.Io.Dir.path.dirname(commands_path)) |parent| {
                    try cwd.createDirPath(io, parent);
                }

                const created = try cwd.createFile(io, commands_path, .{
                    .read = true,
                    .exclusive = true,
                });
                errdefer created.close(io);

                var buffer: [4096]u8 = undefined;
                var writer = created.writerStreaming(io, &buffer);

                try writer.interface.writeAll(inputpkg.command_schema);
                try writer.interface.flush();

                break :blk created;
            },
            else => return err,
        };
        defer file.close(io);

        Logger.logAt(
            .info,
            .commands,
            @src(),
            "loaded commands",
            .{}
        );
    }
};


fn commandsPath(
    alloc: std.mem.Allocator,
    environ_map: *std.process.Environ.Map,
) ![]const u8 {
    const config_parent_dir = try file_load.defaultConfigHome(alloc, environ_map);
    defer alloc.free(config_parent_dir);

    return std.Io.Dir.path.join(alloc, &.{ config_parent_dir, "commands.toml" });
}
