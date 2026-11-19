const std = @import("std");
const Io = std.Io;
const App = @import("App.zig");
const Logger = @import("Logger.zig");
const inputpkg = @import("inputpkg.zig");
const gtk = @import("gtk");
const gio = @import("gio");
const gdk  =@import("gdk");

//ui specific
const uipkg = @import("gtkui/uipkg.zig");


pub const std_options: std.Options = .{
    .logFn = @import("Logger.zig").logFn,
    .log_level = .debug,
};

const MachtooGTKCtx = struct {
    app: *App,
    commands_vm: uipkg.CommandsView.Model,
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
        .app = app_ptr,
        .commands_vm = .{
            .storage = &app_ptr.state.commands,
        },
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

    const commands_view_widget = uipkg.CommandsView.create(
        context.app.allocator,
        &context.commands_vm,
    ) catch |err| {
        Logger.logAt(
            .err,
            .app,
            @src(),
            "failed to create commands view: {}",
            .{err},
        );
        return;
    };

    const content = gtk.Box.new(.vertical, 8);
    const search = gtk.SearchEntry.new();
    content.append(search.as(gtk.Widget));

    commands_view_widget.setVexpand(1);
    content.append(commands_view_widget);

    window.setChild(content.as(gtk.Widget));
    window.present();
    _ = search.as(gtk.Widget).grabFocus();
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

    //@TODO: ADD THE REMAINING MODIFIERS
    if (state.super_mask) mods.bits |= inputpkg.key.Mods.super;

    const event: inputpkg.KeyEvent = .{
        .action = .press,
        .physical_key = physical_key,
        .mods = mods
    };

    const handled = app.*.handleKeyEvent(event);
    return @intFromBool(handled);
}
