const std = @import("std");
const path = std.Io.Dir.path;
const Logger = @import("../Logger.zig");

/// Returns absolute path of app configuration file's parent directory.
/// Supports both Linux and macOS environments. Prefers `$XDG_CONFIG_HOME`,
/// but fallsback to `$HOME` otherwise.
pub fn defaultConfigHome(
    alloc: std.mem.Allocator,
    environ_map: *std.process.Environ.Map,
) ![]const u8 {
    if (environ_map.get("XDG_CONFIG_HOME")) |xdg_var| {
        if (xdg_var.len != 0 and path.isAbsolute(xdg_var)) {
            return path.join(alloc, &.{ xdg_var, "machtoo" });
        }
    }

    //fallback to $HOME
    const home = environ_map.get("HOME") orelse return error.HomeFallbackNotSet;

    if (home.len == 0 or !path.isAbsolute(home)) {
        Logger.logAt(
            .err,
            .config,
            @src(),
            "invalid home path: {s}",
            .{home},
        );
        return error.InvalidHome;
    }

    return path.join(alloc, &.{ home, ".config", "machtoo" });
}

/// Recursively walks the given directory, searching for the requested file name + type pattern.
pub fn scanDirectory(
    io: std.Io,
    alloc: std.mem.Allocator,
    dir_path: []const u8,
    file_suffix: []const u8,
) ![]const []const u8 {
    var dir = try std.Io.Dir.cwd().openDir(io, dir_path, .{ .iterate = true });
    defer dir.close(io);

    var walker = try dir.walk(alloc);
    defer walker.deinit();

    var matched_files: std.ArrayList([]const u8) = .empty;
    errdefer {
        for (matched_files.items) |name| alloc.free(name);
        matched_files.deinit(alloc);
    }

    while (try walker.next(io)) |entry| {
        if (entry.kind != .file) continue;

        if (std.mem.endsWith(u8, entry.basename, file_suffix) and 
            entry.basename.len > file_suffix.len) 
        {
            // const file_path = try alloc.dupe(u8, entry.path);
            const file_path = try path.join(alloc, &.{ dir_path, entry.path });
            errdefer alloc.free(file_path);
            try matched_files.append(alloc, file_path);
        }
    }

    return try matched_files.toOwnedSlice(alloc);
}

pub const LineIterator = struct {
    lines: std.mem.SplitIterator(u8, .scalar),

     pub fn init(file_content: []const u8) LineIterator {
         const lines = std.mem.splitScalar(u8, file_content, '\n');
         return .{ .lines = lines };
     }

    pub fn next(self: *LineIterator) ?[]const u8 {
        return self.lines.next();
    }
};
