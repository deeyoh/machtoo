pub const Config = @import("input/Config.zig");
pub const commands = @import("input/commands.zig");
pub const default_config = @embedFile("default_config");
pub const command_schema = @embedFile("command_schema");
pub const key = @import("input/key.zig");
pub const KeyEvent = @import("input/KeyEvent.zig");
pub const Binding = @import("input/Binding.zig");

const builtin = @import("builtin");

pub const keycodes = switch (builtin.os.tag) {
    .linux => @import("input//keycodes_linux.zig"),
    .macos => @import("input/keycodes_macos.zig"),
    else => @compileError("Unsupported keycode platform"),
};
