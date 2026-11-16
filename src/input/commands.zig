
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

        //begin parsing the TOML file
        //owns its own TOML parser. This is not needed anywhere else
        //other than the load section
        var parser = toml.Parser(Command).init(alloc);
        parser.options.disallow_unknown_fields = true;
        defer parser.deinit();

        var result = parser.parseFile(io, commands_path) catch |err| {
            if (parser.error_info) |info| {
                switch (info) {
                    .parse => |position| {
                        Logger.logAt(
                            .err,
                            .commands,
                            @src(),
                            "TOML parse failed: {s}, line {d}, position {d}",
                            .{
                                @errorName(err),
                                position.line,
                                position.pos,
                            },
                        );
                    },
                    .unknown_fields => |unknown| {
                        for (unknown.keys) |key| {
                            Logger.logAt(
                                .err,
                                .commands,
                                @src(),
                                "Unknown TOML field: {s}",
                                .{key},
                            );
                        }
                    },
                    else => {
                        Logger.logAt(
                            .err,
                            .commands,
                            @src(),
                            "Failed to load commands: {s}",
                            .{@errorName(err)},
                        );
                    },
                }
            }
            return err;
        };
        defer result.deinit();

        const config = result.value;
        const metadata = config.metadata;

        Logger.logAt(
            .info,
            .commands,
            @src(),
            \\metadata:
            \\  schema_version: {d}
            \\  id: {s}
            \\  name: {s}
            \\  notes: {s}
            ,
            .{
                metadata.schema_version,
                metadata.id,
                metadata.name,
                metadata.notes,
            },
        );

        for (metadata.category) |category| {
            Logger.logAt(.info, .commands, @src(), "  category: {s}", .{category});
        }

        for (metadata.tags) |tag| {
            Logger.logAt(.info, .commands, @src(), "  tag: {s}", .{tag});
        }

        for (metadata.aliases) |alias| {
            Logger.logAt(.info, .commands, @src(), "  alias: {s}", .{alias});
        }

        Logger.logAt(
            .info,
            .commands,
            @src(),
            \\action:
            \\  context: {s}
            \\  usage: {s}
            ,
            .{
                config.action.context,
                config.action.usage,
            },
        );

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
