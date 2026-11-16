const Command = @This();

pub const Metadata = struct {
    schema_version: u8,
    id: []const u8,
    name: []const u8,
    description: []const u8,
    category: []const []const u8,
    tags: []const []const u8,
    aliases: []const []const u8,
    notes: []const u8,
};

pub const Action = struct {
    context: []const u8,
    usage: []const u8,
};

metadata: Metadata,
action: Action,
