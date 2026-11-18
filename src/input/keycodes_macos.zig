const PhysicalKey = @import("key.zig").PhysicalKey;

/// macOS virtual keycodes describe physical keyboard positions.
/// Unknown or not-yet-supported keys remain unidentified.
///
/// Keycode Reference: https://gist.github.com/eegrok/949034
pub fn translate(code: u32) PhysicalKey {
    return switch (code) {
        0x00 => .key_a,
        0x01 => .key_s,
        0x02 => .key_d,
        0x03 => .key_f,
        0x04 => .key_h,
        0x05 => .key_g,
        0x06 => .key_z,
        0x07 => .key_x,
        0x08 => .key_c,
        0x09 => .key_v,
        0x0B => .key_b,
        0x0C => .key_q,
        0x0D => .key_w,
        0x0E => .key_e,
        0x0F => .key_r,
        0x10 => .key_y,
        0x11 => .key_t,
        0x1F => .key_o,
        0x20 => .key_u,
        0x22 => .key_i,
        0x23 => .key_p,
        0x24 => .enter,
        0x25 => .key_l,
        0x26 => .key_j,
        0x28 => .key_k,
        0x2C => .slash,
        0x2D => .key_n,
        0x2E => .key_m,
        0x30 => .tab,
        0x31 => .space,
        0x33 => .backspace,
        // 0x34 => .enter, // PowerBook Enter
        0x35 => .escape,
        0x4C => .enter, // Keypad Enter
        else => .unidentified,
    };
}
