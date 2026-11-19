const std = @import("std");
const Io = std.Io;
const App = @import("App.zig");
const Logger = @import("Logger.zig");
const inputpkg = @import("inputpkg.zig");
const gtk = @import("gtk");
const gio = @import("gio");
const gdk  =@import("gdk");

pub const std_options: std.Options = .{
    .logFn = @import("Logger.zig").logFn,
    .log_level = .debug,
};

const MachtooGTKCtx = struct {
    app: *App,
};

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const io = init.io;
    const environ_map = init.environ_map;

    const app_ptr = try App.create(alloc, io, environ_map);
    defer app_ptr.destroy();

    const gtk_app = gtk.Application.new("com.deeyoh.machtoo", .{});
    defer gtk_app.unref();

    var context: MachtooGTKCtx = .{
        .app = app_ptr
    };

    _ = gio.Application.signals.activate.connect(
        gtk_app,
        *MachtooGTKCtx,
        activate,
        &context,
        .{},
    );

    _ = gtk_app.as(gio.Application).run(0, null);
}

fn activate(app: *gtk.Application, context: *MachtooGTKCtx) callconv(.c) void {
    const gtk_window_ptr = gtk.ApplicationWindow.new(app);
    const window = gtk_window_ptr.as(gtk.Window);

    const keys = gtk.EventControllerKey.new();

    _ = gtk.EventControllerKey.signals.key_pressed.connect(
        keys,
        *App,
        onKeyPressed,
        context.app,
        .{},
    );

    keys.as(gtk.EventController).setPropagationPhase(.capture);
    window.as(gtk.Widget).addController(keys.as(gtk.EventController));

    window.setTitle("Machtoo");
    window.setDefaultSize(800, 600);

    const label_ptr = gtk.Label.new("Hello from Zig GTK!");
    window.setChild(label_ptr.as(gtk.Widget));
    window.present();
}

fn onKeyPressed(
    _: *gtk.EventControllerKey,
    keyval: c_uint,
    keycode: c_uint,
    state: gdk.ModifierType,
    app: *App,
) callconv(.c) c_int {
    _ = keyval;
    // Logger.logAt(
    //     .info,
    //     .app,
    //     @src(),
    //     // "keyval={d} | keycode={d} | mods={any}",
    //     "Pressed: {d}",
    //     // .{ keyval, keycode, state }
    //     .{ keycode }
    // );

    const physical_key = inputpkg.keycodes.translate(keycode);

    Logger.logAt(
        .info,
        .app,
        @src(),
        "Pressed: {}",
        .{ physical_key }
    );

    var mods: inputpkg.key.Mods = .{};
    if (state.super_mask) mods.bits |= inputpkg.key.Mods.super;

    const event: inputpkg.KeyEvent = .{
        .action = .press,
        .physical_key = physical_key,
        .mods = mods
    };

    const handled = app.*.handleKeyEvent(event);
    return @intFromBool(handled);
}
