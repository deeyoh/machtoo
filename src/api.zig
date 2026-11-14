export fn machtoo_add(a: i32, b: i32) i32 {
    return a + b;
}

export fn machtoo_app_create() ?*MachtooApp {
    const api_app_ptr = ApiApp.create() catch return null;
    const public_app_ptr: *MachtooApp = @ptrCast(api_app_ptr);
    return public_app_ptr;
}

export fn machtoo_app_destroy(handle: ?*MachtooApp) void {
    const public_ptr_handle = handle orelse return;
    const api_app_ptr = alignHandle(public_ptr_handle);
    api_app_ptr.destroy();
}

const std = @import("std");
const ApiApp = @import("App.zig").ApiApp;

/// Public handle type that matches the MachtooApp struct
/// in the header file. The internal fields are intentionally
/// unavailable.
const MachtooApp = opaque {};

/// Restores proper alignment from the opaque public app pointer
/// to the Zig internal `ApiApp` pointer.
fn alignHandle(handle: *MachtooApp) *ApiApp {
    return @ptrCast(@alignCast(handle));
}
