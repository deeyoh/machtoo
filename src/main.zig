const std = @import("std");
const Io = std.Io;
const gtk = @import("gtk");
const gio = @import("gio");

pub fn main(init: std.process.Init) !void {
    const gtk_app = gtk.Application.new("com.deeyoh.machtoo", .{});
    defer gtk_app.unref();

    _ = gio.Application.signals.activate.connect(
        gtk_app,
        ?*anyopaque,
        activate,
        null,
        .{},
    );

    _ = init;
    _ = gtk_app.as(gio.Application).run(0, null);
}

fn activate(app: *gtk.Application, _: ?*anyopaque) callconv(.c) void {
    const gtk_window_ptr = gtk.ApplicationWindow.new(app);
    const window = gtk_window_ptr.as(gtk.Window);

    window.setTitle("Machtoo");
    window.setDefaultSize(800, 600);

    const label_ptr = gtk.Label.new("Hello from Zig GTK!");
    window.setChild(label_ptr.as(gtk.Widget));
    window.present();
}
