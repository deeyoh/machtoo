const std = @import("std");
const gtk = @import("gtk");
const inputpkg = @import("../inputpkg.zig");

pub const Model = struct {
    const Self = @This();
    storage: *inputpkg.commands.Storage,

    fn count(self: *const Self) usize {
        return self.storage.commands.count();
    }
};

pub fn create(
    alloc: std.mem.Allocator,
    model: *Model,
) !*gtk.Widget {
    const list = gtk.ListBox.new();

    for (0..model.count()) |idx| {
        const name = try alloc.dupeSentinel(u8, model.*.storage.commands.values()[idx].metadata.name, 0);
        defer alloc.free(name);

        const label = gtk.Label.new(name);
        label.setXalign(0);
        list.append(label.as(gtk.Widget));
    }

    const scroll = gtk.ScrolledWindow.new();
    scroll.setChild(list.as(gtk.Widget));
    return scroll.as(gtk.Widget);
}
