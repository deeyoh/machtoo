const KeyEvent = @This();

const key = @import("key.zig");
const Binding = @import("Binding.zig");
const Action = @import("../corepkg.zig").Action;

action: key.ActionVariant,
physical_key: key.PhysicalKey,
mods: key.Mods,

pub const Handler = struct {
    current: ?*const Binding.Tree = null,
    root: *const Binding.Tree,

    pub const Result = union(enum) {
        no_result,
        pending,
        action: Action
    };

    pub fn init(root: *const Binding.Tree) Handler {
        return .{ .root = root };
    }

    pub fn reset(self: *Handler) void {
        self.current = self.root;
    }

    pub fn feedKeyEvent(
        self: *Handler,
        event: KeyEvent,
    ) Result {
        if (event.action != .press) return .no_result;
        if (event.physical_key == .unidentified) return .no_result;

        const current = self.current orelse self.root;
        const value = findMatch(current, event) orelse {
            self.reset();
            return .no_result;
        };

        switch (value) {
            .leaf_node => |action| {
                self.reset();
                return .{ .action = action };
            },
            .leader => |child_set| {
                self.current = child_set;
                return .pending;
            }
        }
    }

    pub fn findMatch(current: *const Binding.Tree, event: KeyEvent) ?Binding.Tree.Value{
        return current.binding_map.get(.{
            .physical_key = event.physical_key,
            .mods = event.mods,
        });
    }
};
