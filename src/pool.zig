const std = @import("std");

const IdentIndex = u32;
const ConstIndex = u32;

pub const DataPool = struct {
    const Tag = enum(u3) { int, string };
    const Value = struct {
        tag: Tag,
        data: Data,

        const Data = union(Tag) {
            int: i32,
            string: []const u8,
        };
    };

    identifiers: std.StringArrayHashMap([]const u8),
    constants: std.StringArrayHashMap(Value),
};
