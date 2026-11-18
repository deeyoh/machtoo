const Binding = @This();

const std = @import("std");
const Action = @import("../corepkg.zig").Action; 
const key = @import("key.zig");

trigger: Trigger,

/// A prefix tree of bindings. A leaf node represents a valid
/// key to action relationship. Progress through the tree via prefix
/// leader matching.
pub const Tree = struct {
    const Map = std.array_hash_map.Custom(
        Trigger,
        Value,
        Context(Trigger),
        true,
    );

    pub const Value = union(enum) {
        leaf_node: Action,
        leader: *Tree,
    };

    binding_map: Map = .{},

    pub fn deinit(self: *Tree, alloc: std.mem.Allocator) void {
        for (self.binding_map.values()) |val| {
            switch (val) {
                .leaf_node => {},
                .leader => |child| {
                    child.deinit(alloc);
                    alloc.destroy(child);
                }
            }
        }
        self.binding_map.deinit(alloc);
        self.* = .{};
    }

    /// This defines how the hash map gets the hash key and checks for equality.
    fn Context(comptime KeyType: type) type {
        return struct {
            pub fn hash(ctx: @This(), k: KeyType) u32 {
                _ = ctx;
                return @truncate(k.hash());
            }

            pub fn eql(
                ctx: @This(),
                a: KeyType,
                b: KeyType,
                b_index: usize,
            ) bool {
                _ = ctx;
                _ = b_index;
                return a.bindingEql(b);
            }
        };
    }
};


pub const Trigger = struct {
    physical_key: key.PhysicalKey,
    mods: key.Mods = .{},

    pub fn hash(self: Trigger) u64 {
        var hasher = std.hash.Wyhash.init(0);

        std.hash.autoHash(&hasher, self.physical_key);
        std.hash.autoHash(&hasher, self.mods.bits);

        return hasher.final();
    }

    pub fn bindingEql(self: Trigger, other: Trigger) bool {
        return self.physical_key == other.physical_key and 
            self.mods.bits == other.mods.bits;
    }

};
