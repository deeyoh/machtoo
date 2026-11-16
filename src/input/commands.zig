
const std = @import("std");
const toml = @import("toml");
const Command = @import("../corepkg.zig").Command;
const Logger = @import("../Logger.zig");
const file_load = @import("file_load.zig");
const inputpkg = @import("../inputpkg.zig");

const JJ_REBASE_COMMAND_FILE_NAME: []const u8 = "jj-rebase-command.toml";

pub const Storage = struct {
    const Map = std.array_hash_map.String(Command);

    commands: Map = .{},
    arena: std.heap.ArenaAllocator,

    pub fn deinit(self: *Storage, alloc: std.mem.Allocator) void {
        self.commands.deinit(alloc);
        self.arena.deinit();
        self.* = undefined;
    }


    pub fn init(backing_alloc: std.mem.Allocator) Storage {
        return .{
            .arena = std.heap.ArenaAllocator.init(backing_alloc)
        };
    }

    /// Recursively reads defined command files in config directory,
    /// inserting them into the storage's array hash map, using its `id`
    /// as the key. If there are no existing command files that match
    /// `command.toml` file suffix, it will create an example command
    /// file that demonstrates the acceptable schema.
    pub fn load(
        self: *Storage,
        io: std.Io,
        alloc: std.mem.Allocator,
        environ_map: *std.process.Environ.Map,
    ) !void {
        const config_parent_dir =
            try file_load.defaultConfigHome(alloc, environ_map);
        defer alloc.free(config_parent_dir);

        var command_file_buf: std.ArrayList([]const u8) = .empty;
        defer {
            for (command_file_buf.items) |file_path| alloc.free(file_path);
            command_file_buf.deinit(alloc);
        }

        try std.Io.Dir.cwd().createDirPath(io, config_parent_dir);

        try findCommandFiles(
            io,
            alloc,
            &command_file_buf,
            config_parent_dir,
        );

        if (command_file_buf.items.len == 0) {
            const example_file_path = try createExampleCommandFile(io, alloc, config_parent_dir);
            //nothing previously found, add to buf to continue with parsing process
            command_file_buf.append(alloc, example_file_path) catch |err| {
                alloc.free(example_file_path);
                return err;
            };
        }

        Logger.logAt(
            .info,
            .commands,
            @src(),
            "total command files discovered: {}",
            .{command_file_buf.items.len},
        );

        //begin parsing the TOML file
        //owns its own TOML parser. This is not needed anywhere else
        //other than the load section
        var parser = toml.Parser(Command).init(alloc);
        parser.options.disallow_unknown_fields = true;
        defer parser.deinit();

        for (command_file_buf.items) |file_path| {
            var result = parser.parseFile(io, file_path) catch |err| {
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

            const owned_command = try self.cloneCommand(config);
            try self.commands.put(alloc, owned_command.metadata.id, owned_command);
        }
    }

    fn cloneCommand(self: *Storage, source: Command) !Command {
        const alloc = self.arena.allocator();

        return .{
            .metadata = .{
                .schema_version = source.metadata.schema_version,
                .id = try alloc.dupe(u8, source.metadata.id),
                .name = try alloc.dupe(u8, source.metadata.name),
                .description = try alloc.dupe(u8, source.metadata.description),
                .category = try cloneStrings(alloc, source.metadata.category),
                .tags = try cloneStrings(alloc, source.metadata.tags),
                .aliases = try cloneStrings(alloc, source.metadata.aliases),
                .notes = try alloc.dupe(u8, source.metadata.notes),
            },
            .action = .{
                .context = try alloc.dupe(u8, source.action.context),
                .usage = try alloc.dupe(u8, source.action.usage),
            },
        };
    }

    fn cloneStrings(
        alloc: std.mem.Allocator,
        strings: []const []const u8,
    ) ![]const []const u8 {
        const copies = try alloc.alloc([]const u8, strings.len);

        for (strings, 0..) |string, i| {
            copies[i] = try alloc.dupe(u8, string);
        }

        return copies;
    }
};

/// Fills in a given array list of the paths of user's command files
fn findCommandFiles(
    io: std.Io,
    alloc: std.mem.Allocator,
    buf: *std.ArrayList([]const u8),
    commands_directory: []const u8,
) !void {
    //scan directory, mutate its buf
    const command_files = try file_load.scanDirectory(
        io,
        alloc,
        commands_directory,
        "command.toml",
    );
    defer alloc.free(command_files);

    errdefer {
        for (command_files) |file| alloc.free(file);
    }

    try buf.*.appendSlice(alloc, command_files);
}

/// Creates a file containing an example command schema.
/// Returns the absolute path of the created file.
fn createExampleCommandFile(
    io: std.Io,
    alloc: std.mem.Allocator,
    parent_dir: []const u8,
) ![]const u8 {
    const example_command_path =
        try std.Io.Dir.path.join(alloc, &.{ parent_dir, JJ_REBASE_COMMAND_FILE_NAME });
    errdefer alloc.free(example_command_path);

    Logger.logAt(
        .info,
        .commands,
        @src(),
        "commands not found; creating example: {s}",
        .{example_command_path},
    );

    const cwd = std.Io.Dir.cwd();

    // if (std.Io.Dir.path.dirname(example_command_path)) |parent| {
    //     try cwd.createDirPath(io, parent);
    // }

    const created = try cwd.createFile(io, example_command_path, .{
        .read = true,
        .exclusive = true,
    });
    defer created.close(io);

    var buffer: [4096]u8 = undefined;
    var writer = created.writerStreaming(io, &buffer);

    try writer.interface.writeAll(inputpkg.command_schema);
    try writer.interface.flush();

    return example_command_path;
}
