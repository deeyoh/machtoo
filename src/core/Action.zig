const Action = @This();

const std = @import("std");

value: Value,

pub const Value = union(enum) {
    hide_panel: void,
    show_panel: void,
};

pub fn parse(action_text: []const u8) !Action {
    //needs to check if valid action (if in actions enum)
    //if so, create an action with its payload, if necessary
    const text = std.mem.trim(u8, action_text, " \t\r\n");

    // ':' denotes payload for an action
    const separator = std.mem.findScalar(u8, text, ':');

    const name = std.mem.trim(
        u8,
        text[0..separator orelse text.len],
        " \t\r\n",
    );

    const payload: ?[]const u8 = if (separator) |index|
        std.mem.trim(u8, text[index+1..], " \t\r\n")
    else
        null;

    const tag = std.meta.stringToEnum(
        std.meta.Tag(Value),
        name,
    ) orelse return error.UnknownAction;

    switch (tag) {
        .hide_panel, .show_panel => {
            if (payload != null) {
                return error.UnexpectedActionPayload;
            }

            return .{
                .value = switch (tag) {
                    .hide_panel => .hide_panel,
                    .show_panel => .show_panel,
                },
            };
        },
    }
}

pub const Handler = struct {
    ptr: *const anyopaque,
    hideMainWindowFn: *const fn (ptr: *const anyopaque) callconv(.c) void,
    showMainWindowFn: *const fn (ptr: *const anyopaque) callconv(.c) void,

    pub fn hideMainWindow(self: Handler)  void {
        return self.hideMainWindowFn(self.ptr);
    }

    pub fn showMainWndow(self: Handler) void {
        return self.showMainWindowFn(self.ptr);
    }
};
