
const std = @import("std");

/// Runtime for application.
pub const Runtime = enum {
    /// Does not create an executable. Only should be used
    /// when creating the static library for macOS.
    none,

    /// GTK4 runtime. This is a full windowed application.
    gtk,

    pub fn default(target: std.Target) Runtime {
        return switch (target.os.tag) {
            .linux, .freebsd => .gtk,
            else => .none
        };
    }
};
