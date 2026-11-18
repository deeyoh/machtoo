const Config = @This();

const std = @import("std");
const Logger = @import("../Logger.zig");
const file_load = @import("file_load.zig");
const inputpkg = @import("../inputpkg.zig");
const Binding = @import("Binding.zig");

bindings: inputpkg.Binding.Tree = .{},

pub fn load(
    self: *Config,
    io: std.Io,
    alloc: std.mem.Allocator,
    environ_map: *std.process.Environ.Map,
) !void {
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

    var buffer: [4096]u8 = undefined;
    var reader = file.reader(io, &buffer);

    const contents = try reader.interface.allocRemaining(alloc, .limited(1024 * 1024));
    defer alloc.free(contents);

    var iter = file_load.LineIterator.init(contents);

    while (iter.next()) |line| {
        if (std.mem.trim(u8, line, " \t").len == 0) continue;

        const separator = std.mem.findScalar(u8, line, '=') orelse
            return error.InvalidConfigSyntax;

        const entry_type = std.mem.trim(u8, line[0..separator], " \t");
        const entry_value = std.mem.trim(u8, line[separator + 1..], " \t");

        try Entry.parseAndApply(
            alloc,
            &self.bindings,
            entry_type,
            entry_value,
        );

        Logger.logAt(
            .info,
            .config,
            @src(),
            "entry: {s} | {s}",
            .{entry_type, entry_value},
        );
    }
}

fn configPath(
    alloc: std.mem.Allocator,
    environ_map: *std.process.Environ.Map
) ![]const u8 {
    const config_parent_dir = try file_load.defaultConfigHome(alloc, environ_map);
    defer alloc.free(config_parent_dir);

    return std.Io.Dir.path.join(alloc, &.{ config_parent_dir, "config.machtoo" });
}


const Entry = struct {
    value: Value,

    pub fn parseAndApply(
        alloc: std.mem.Allocator,
        bindings: *Binding.Tree,
        entry_type: []const u8,
        entry_value: []const u8,
    ) !void {
        const tag = std.meta.stringToEnum(
            std.meta.Tag(Value),
            entry_type,
        ) orelse return error.UnknownConfigEntryType;

        switch (tag) {
            .keybind => try bindings.parseAndPut(alloc, entry_value),
        }
    }
};

pub const Value = union(enum) {
    keybind: Binding,
};
