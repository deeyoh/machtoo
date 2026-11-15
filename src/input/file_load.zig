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
