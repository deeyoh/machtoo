const App = @This();

const std = @import("std");
const builtin = @import("builtin");
const Logger = @import("Logger.zig");
const inputpkg = @import("inputpkg.zig");
const Config = @import("inputpkg.zig").Config;

allocator: std.mem.Allocator,
state: GlobalState,

pub const GlobalState = struct {
    config: inputpkg.Config,
};

pub fn create(
    alloc: std.mem.Allocator,
    io: std.Io,
    environ_map: *std.process.Environ.Map
) !*App {
    const app_ptr = try alloc.create(App);
    errdefer alloc.destroy(app_ptr);

    try Logger.init(io, environ_map, alloc);
    errdefer Logger.deinit();

    var config: Config = .{};
    try config.load(io, alloc, environ_map);

    app_ptr.* = .{
        .allocator = alloc,
        .state = .{
            .config = config,
        },
    };

    Logger.logAt(
        .debug,
        .app,
        @src(),
        "successfully created core app",
        .{},
    );

    return app_ptr;
}

pub fn destroy(self: *App) void {
    Logger.deinit();
    self.allocator.destroy(self);
}

/// Wrapper struct of `App` for C API. Bootstraps a safe allocator backed
/// by a page allocator if in debug mode; otherwise uses C allocator. Replaces
/// Zig's juicy main, as it passes in environment variables and an I/O backend.
pub const ApiApp = struct {
    const Self = @This();

    // No safe allocator state is needed in release builds. Swift relies on
    // libc, so in releases, that is preferred (C allocator in Zig).
    const use_safe_allocator = builtin.optimize == .debug;

    safe_allocator: if (use_safe_allocator) std.heap.SafeAllocator else void,
    app: *App,
    threaded: std.Io.Threaded,

    pub fn create() !*Self {
        const self = try std.heap.c_allocator.create(ApiApp);
        errdefer std.heap.c_allocator.destroy(self);

        self.* = .{
            .safe_allocator = if (use_safe_allocator)
                .init(std.heap.page_allocator, .{})
            else {},
            .app = undefined,
            .threaded = undefined,
        };

        const allocator = if (use_safe_allocator)
            self.safe_allocator.allocator()
        else
            std.heap.c_allocator;
        errdefer if (use_safe_allocator) {
            _ = self.safe_allocator.deinit();
        };

        self.threaded = std.Io.Threaded.init(allocator, .{});
        errdefer self.threaded.deinit();

        var environ_map = std.process.Environ.Map.init(allocator);
        defer environ_map.deinit();

        for ([_][:0]const u8{ 
            "HOME",
            "XDG_STATE_HOME",
            "XDG_CONFIG_HOME",
        }) |key| {
            if (std.c.getenv(key.ptr)) |value| {
                try environ_map.put(key, std.mem.span(value));
            }
        }

        self.app = try App.create(
            allocator,
            self.threaded.io(),
            &environ_map,
        );

        return self;
    }

    pub fn destroy(self: *ApiApp) void {
        Logger.logAt(
            .info,
            .app,
            @src(),
            "ApiApp.destroy entered; safe allocator enabled: {}",
            .{ use_safe_allocator },
        );
        self.app.destroy();

        self.threaded.deinit();

        if (use_safe_allocator) {
            _ = self.safe_allocator.deinit();
        }

        std.heap.c_allocator.destroy(self);
    }
};
