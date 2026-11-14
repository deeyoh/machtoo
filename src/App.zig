const App = @This();

const std = @import("std");
const builtin = @import("builtin");

allocator: std.mem.Allocator,

pub fn create(alloc: std.mem.Allocator) !*App {
    const app_ptr = try alloc.create(App);

    app_ptr.* = .{
        .allocator = alloc,
    };

    return app_ptr;
}

pub fn destroy(self: *App) void {
    self.allocator.destroy(self);
}


/// Wrapper struct of `App` for C API. Bootstraps a safe allocator backed
/// by a page allocator if in debug mode; otherwise uses C allocator.
pub const ApiApp = struct {
    const Self = @This();

    // No safe allocator state is needed in release builds. Swift relies on
    // libc, so in releases, that is preferred (C allocator in Zig).
    const use_safe_allocator = builtin.optimize == .debug;

    safe_allocator: if (use_safe_allocator) std.heap.SafeAllocator else void,
    app: *App,

    pub fn create() !*Self {
        const self = try std.heap.c_allocator.create(ApiApp);
        errdefer std.heap.c_allocator.destroy(self);

        self.* = .{
            .safe_allocator = if (use_safe_allocator)
                .init(std.heap.page_allocator, .{})
            else {},
            .app = undefined,
        };

        const allocator = if (use_safe_allocator)
            self.safe_allocator.allocator()
        else
            std.heap.c_allocator;
        errdefer if (use_safe_allocator) {
            _ = self.safe_allocator.deinit();
        };

        self.app = try App.create(allocator);
        return self;
    }

    pub fn destroy(self: *ApiApp) void {
        self.app.destroy();

        if (use_safe_allocator) {
            _ = self.safe_allocator.deinit();
        }

        std.heap.c_allocator.destroy(self);
    }
};
