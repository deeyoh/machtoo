const App = @This();

const std = @import("std");
const builtin = @import("builtin");
const Logger = @import("Logger.zig");
const inputpkg = @import("inputpkg.zig");
const ActionHandler = @import("corepkg.zig").Action.Handler;

const Config = inputpkg.Config;
const commands = inputpkg.commands;
const KeyEvent = inputpkg.KeyEvent;

allocator: std.mem.Allocator,
state: GlobalState,

pub const GlobalState = struct {
    config: inputpkg.Config,
    commands: commands.Storage,
    key_handler: KeyEvent.Handler,

    //set within each respective UI via handler register
    action_handler: ?ActionHandler = null,
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
            .commands = commands.Storage.init(alloc),
            .key_handler = undefined,
        },
    };
    errdefer app_ptr.state.commands.deinit(alloc);

    app_ptr.state.key_handler = KeyEvent.Handler.init(
        &app_ptr.state.config.bindings,
    );

    try app_ptr.state.commands.load(
        io,
        alloc,
        environ_map,
    );

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
    self.state.commands.deinit(self.allocator);
    self.state.config.deinit(self.allocator);
    self.allocator.destroy(self);
}

pub fn handleKeyEvent(self: *App, event: KeyEvent) bool {
    switch (self.state.key_handler.feedKeyEvent(event)) {
        .no_result => return false,
        .pending => return true,
        .action => |action| {
            //@TODO: dispatch action
            Logger.logAt(
                .info,
                .app,
                @src(),
                "matching action found: {}",
                .{action},
            );

            //@NOTE: Maybe change to return an error
            const action_handler = self.*.state.action_handler orelse 
                return false;

            switch (action.value) {
                .hide_panel => action_handler.hideMainWindow(),
                .show_panel => action_handler.showMainWndow(),
                .show_create_command_form => {}
            }
            return true;

            // @NOTE: Use `ActionHandler` interface.
            // switch (builtin.os.tag) {
            //     .macos => {
            //         //@TODO: Call API Swift callback to tell Swift to execute its
            //         //UI specific action for particular surface
            //     },
            //     .linux => {
            //         const uipkg = @import("gtkui/uipkg.zig").actions;
            //         _ = uipkg;
            //         //@TODO: Call GTK's action handler
            //         //
            //         // Given some action, we want to execute it within the UI
            //     },
            //     else => @compileError("Unsupported OS selection for key event handler"),
            // }
            // return true;
        },
    }
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

        if (use_safe_allocator) {
            _ = self.safe_allocator.deinit();
        }

        //Logger's deinit placed here instead of within App's destroy
        //to ensure leaks are logged in specified file rather than stderr
        Logger.deinit();

        self.threaded.deinit();

        std.heap.c_allocator.destroy(self);
    }
};
