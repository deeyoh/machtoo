pub const ActionVariant = enum(c_int) {
    release = 0,
    press = 1,
};


/// Physical keys, named after their US-layout positions.
/// These values do not describe the text produced by a keyboard layout
pub const PhysicalKey = enum {
    unidentified,

    key_a,
    key_b,
    key_c,
    key_d,
    key_e,
    key_f,
    key_g,
    key_h,
    key_i,
    key_j,
    key_k,
    key_l,
    key_m,
    key_n,
    key_o,
    key_p,
    key_q,
    key_r,
    key_s,
    key_t,
    key_u,
    key_v,
    key_w,
    key_x,
    key_y,
    key_z,

    slash,
    space,
    escape,
    enter,
    tab,
    backspace,
};

pub const Mods = struct {
    bits: u32 = 0,

    pub const shift: u32 = 1 << 0;
    pub const control: u32 = 1 << 1;
    pub const alt: u32 = 1 << 2;
    pub const super: u32 = 1 << 3;

    pub const mask: u32 = shift | control | alt | super;

    pub fn containers(self: Mods, modifier: u32) bool {
        return self.bits & modifier != 0;
    }
};
