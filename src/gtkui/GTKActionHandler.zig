const GTKActionHandler = @This();

const ActionHandler = @import("../corepkg.zig").Action.Handler;
const App = @import("../App.zig");
const gtk = @import("gtk");
const builtin = @import("builtin");

base_window: *gtk.Window,

/// Stores the widget arguments to maintain a stateful
/// list of widget references in order to execute actions.
pub fn init(
    window: *gtk.Window,
) GTKActionHandler {
    return .{
        .base_window = window,
    };
}

/// Mutates the app's action handler state to contain this handler.
/// Uses the `ActionHandler` interface.
pub fn register(self: *const GTKActionHandler, app_ptr: *App) void {
    app_ptr.*.state.action_handler = self.actionHandler();
}

fn hideMainWindow(ptr: *const anyopaque) callconv(.c) void {
    const self: *const GTKActionHandler = @ptrCast(@alignCast(ptr));
    // self.base_window.as(gtk.Widget).setVisible(0);
    self.base_window.destroy();
}

//@TODO: THIS DOES NOT WORK. On X11 and Wayland, we do not use
// global event key listener (not allowed)
fn showMainWindow(ptr: *const anyopaque) callconv(.c) void {
    const self: *const GTKActionHandler = @ptrCast(@alignCast(ptr));
    self.base_window.present();
}

fn actionHandler(self: *const GTKActionHandler) ActionHandler {
    return .{
        .ptr = self,
        .hideMainWindowFn = hideMainWindow,
        .showMainWindowFn = showMainWindow,
    };
}
