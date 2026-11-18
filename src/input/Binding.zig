const Binding = @This();

const std = @import("std");
const Action = @import("../corepkg.zig").Action; 
const key = @import("key.zig");
const Logger = @import("../Logger.zig");

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

    /// Parses config keybind input value and inserts into the bind prefix
    /// tree if valid.
    pub fn parseAndPut(
        self: *Tree,
        alloc: std.mem.Allocator,
        keybind_value: []const u8,
    ) !void {
        const separator = std.mem.findScalar(u8, keybind_value, '=') orelse
            return error.InvalidConfigSyntax;

        const trigger_text = std.mem.trim(u8, keybind_value[0..separator], " \t\r\n");
        const action_text = std.mem.trim(u8, keybind_value[separator + 1..], " \t\r\n");

        const trigger_sequence = try parseSequence(alloc, trigger_text);
        defer alloc.free(trigger_sequence);

        const action = try Action.parse(action_text);

        try self.putSequence(alloc, trigger_sequence, action);
    }

    fn putSequence(
        self: *Tree,
        alloc: std.mem.Allocator,
        sequence: []const Trigger,
        action: Action,
    ) !void {
        if (sequence.len == 0) return error.EmptySequence;

        const trigger = sequence[0];
        const is_final = sequence.len == 1;

        if (self.binding_map.getPtr(trigger)) |existing| {
            switch (existing.*) {
                .leaf_node => {
                    if (!is_final) return error.BindingPrefixConflict;
                    existing.* = .{ .leaf_node = action };
                },
                .leader => |child_set| {
                    if (is_final) return error.BindingPrefixConflict;
                    try child_set.putSequence(alloc, sequence[1..], action);
                },
            }
            return;
        }

        if (is_final) {
            try self.binding_map.put(alloc, trigger, .{ .leaf_node = action });
        } else {
            const child = try alloc.create(Tree);
            child.* = .{};
            errdefer {
                child.deinit(alloc);
                alloc.destroy(child);
            }

            try child.putSequence(alloc, sequence[1..], action);
            try self.binding_map.put(alloc, trigger, .{ .leader = child });
        }
    }

    /// Parses each '>'-separated trigger step in one key press.
    fn parseSequence(
        alloc: std.mem.Allocator,
        trigger_text: []const u8
    ) ![]Trigger {
        var sequence: std.ArrayList(Trigger) = .empty;
        errdefer sequence.deinit(alloc);

        var steps = std.mem.splitScalar(u8, trigger_text, '>');

        while (steps.next()) |step| {
            const trigger = try Trigger.parse(step);
            try sequence.append(alloc, trigger);
        }

        return try sequence.toOwnedSlice(alloc);
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

    /// Parses one trigger step in a binding, such as "j", "tab" or "ctrl+shift+j".
    /// It does not parse an entire sequence. Each step in a possible sequence is
    /// noted via the '>' text.
    pub fn parse(sequence_step: []const u8) !Trigger {
        const trimmed = std.mem.trim(u8, sequence_step, " \t\r\n");

        if (trimmed.len == 0) return error.EmptyTrigger;

        var parts = std.mem.splitScalar(u8, trimmed, '+');
        var part = parts.next() orelse return error.EmptyTrigger;

        var mods: key.Mods = .{};

        while (parts.next()) |next| {
            const modifier = std.mem.trim(u8, part, " \t");

            const flag: u32 = if (std.mem.eql(u8, modifier, "ctrl"))
                key.Mods.control
            else if (std.mem.eql(u8, modifier, "alt"))
                key.Mods.alt
            else if (std.mem.eql(u8, modifier, "shift"))
                key.Mods.shift
            else if (std.mem.eql(u8, modifier, "super"))
                key.Mods.super
            else
                return error.UnknownModifier;

            if (mods.contains(flag)) return error.DuplicateModifier;
            mods.bits |= flag;

            part = next;
        }

        const name = std.mem.trim(u8, part, " \t");
        if (name.len == 0) return error.EmptyKey;

        return .{
            .physical_key = try parsePhysicalKey(name),
            .mods = mods,
        };
    }

    /// Parses physical input key text to a `PhysicalKey`. Accepts
    /// "a", "A", "key_a", and special keys, such as "escape", and "slash".
    fn parsePhysicalKey(key_text: []const u8) !key.PhysicalKey {
        if (key_text.len == 1 and std.ascii.isAlphabetic(key_text[0])) {
            const name = [_]u8{
                'k', 'e', 'y', '_',
                std.ascii.toLower(key_text[0]),
            };

            return std.meta.stringToEnum(key.PhysicalKey, &name) orelse {
                Logger.logAt(
                    .err,
                    .config,
                    @src(),
                    "invalid physical key: {s}",
                    .{key_text},
                );
                return error.InvalidPhysicalKey;
            };
        }

        return std.meta.stringToEnum(key.PhysicalKey, key_text) orelse {
            Logger.logAt(
                .err,
                .config,
                @src(),
                "invalid physical key: {s}",
                .{key_text},
            );
            return error.InvalidPhysicalKey;
        };
    }
};
