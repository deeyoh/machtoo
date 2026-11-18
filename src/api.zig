export fn machtoo_add(a: i32, b: i32) i32 {
    return a + b;
}

export fn machtoo_app_create() ?*MachtooApp {
    const api_app_ptr = ApiApp.create() catch |err| {
        Logger.logAt(
            .err,
            .api,
            @src(),
            "machtoo_app_created failed: {s}",
            .{@errorName(err)},
        );
        return null;
    };
    const public_app_ptr: *MachtooApp = @ptrCast(api_app_ptr);
    return public_app_ptr;
}

export fn machtoo_app_destroy(handle: ?*MachtooApp) void {
    const public_ptr_handle = handle orelse return;
    const api_app_ptr = alignHandle(public_ptr_handle);
    api_app_ptr.destroy();
}

const ApiString = extern struct {
    ptr: ?[*]const u8,
    len: usize,
};

const ApiCommand = extern struct {
    id: ApiString,
    name: ApiString,
    description: ApiString,
};

export fn machtoo_app_read_commands(
    handle: ?*MachtooApp,
    out_commands: ?[*]ApiCommand,
    capacity: usize,
) usize {
    const public_handle = handle orelse return 0;
    const api_app = alignHandle(public_handle);

    const commands = api_app.app.state.commands.getCommands();

    const output = out_commands orelse return commands.len;
    const write_count = @min(capacity, commands.len);

    for (commands[0..write_count], 0..) |command, i| {
        output[i] = .{
            .id = apiString(command.metadata.id),
            .name = apiString(command.metadata.name),
            .description = apiString(command.metadata.description),
        };
    }

    return commands.len;
}

const ApiKeyEvent = extern struct {
    action: c_int,
    native_keycode: u32,
    mods: u32,
};

export fn machtoo_app_key_event(
    handle: ?*MachtooApp,
    event: ApiKeyEvent,
) bool {
    const public_handle = handle orelse return false;
    const api_app = alignHandle(public_handle);

    const action: inputpkg.key.ActionVariant = switch (event.action) {
        0 => .release,
        1 => .press,
        else => return false,
    };

    const translated_event: inputpkg.KeyEvent = .{
        .action = action,
        .physical_key = inputpkg.keycodes_macos.translate(event.native_keycode),
        .mods = .{
            .bits = event.mods & inputpkg.key.Mods.mask,
        },
    };

    return api_app.app.handleKeyEvent(translated_event);
}

const std = @import("std");
const ApiApp = @import("App.zig").ApiApp;
const Logger = @import("Logger.zig");
const inputpkg = @import("inputpkg.zig");

pub const std_options: std.Options = .{
    .logFn = @import("Logger.zig").logFn,
    .log_level = .debug,
};

/// Public handle type that matches the MachtooApp struct
/// in the header file. The internal fields are intentionally
/// unavailable.
const MachtooApp = opaque {};

/// Restores proper alignment from the opaque public app pointer
/// to the Zig internal `ApiApp` pointer.
fn alignHandle(handle: *MachtooApp) *ApiApp {
    return @ptrCast(@alignCast(handle));
}

/// Converts Zig string slice into a valid C-compatible type
fn apiString(value: []const u8) ApiString {
    return .{
        .ptr = if (value.len == 0) null else value.ptr,
        .len = value.len,
    };
}

