const PhysicalKey = @import("key.zig").PhysicalKey;

/// Translates GTK keycodes using the standard Linux X11/Wayland keymap.
/// These keycodes are Linux evdev codes plus 8, not macOS virtual keycodes.
/// Custom X11 keycode mappings may require an XKB-based translation instead.
/// Unknown or not-yet-supported keys remain unidentified.
pub fn translate(keycode: u32) PhysicalKey {
    if (keycode < 8) return .unidentified;

    const evdev = keycode - 8;
    return switch (evdev) {
        1 => .escape,
        14 => .backspace,
        15 => .tab,
        16 => .key_q,
        17 => .key_w,
        18 => .key_e,
        19 => .key_r,
        20 => .key_t,
        21 => .key_y,
        22 => .key_u,
        23 => .key_i,
        24 => .key_o,
        25 => .key_p,
        28 => .enter,
        30 => .key_a,
        31 => .key_s,
        32 => .key_d,
        33 => .key_f,
        34 => .key_g,
        35 => .key_h,
        36 => .key_j,
        37 => .key_k,
        38 => .key_l,
        44 => .key_z,
        45 => .key_x,
        46 => .key_c,
        47 => .key_v,
        48 => .key_b,
        49 => .key_n,
        50 => .key_m,
        53 => .slash,
        57 => .space,
        96 => .enter, // Keypad Enter
        else => .unidentified,
    };
}

test "translate standard GTK Linux keycodes" {
    const std = @import("std");
    try std.testing.expectEqual(PhysicalKey.key_a, translate(38));
    try std.testing.expectEqual(PhysicalKey.key_q, translate(24));
    try std.testing.expectEqual(PhysicalKey.escape, translate(9));
    try std.testing.expectEqual(PhysicalKey.enter, translate(36));
    try std.testing.expectEqual(PhysicalKey.enter, translate(104));
    try std.testing.expectEqual(PhysicalKey.space, translate(65));
    try std.testing.expectEqual(PhysicalKey.unidentified, translate(0));
    try std.testing.expectEqual(PhysicalKey.unidentified, translate(7));
    try std.testing.expectEqual(PhysicalKey.unidentified, translate(8));
    try std.testing.expectEqual(PhysicalKey.unidentified, translate(999));
}
