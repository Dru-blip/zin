const std = @import("std");
const set = @import("indexed_set.zig");
const value = @import("value.zig");

pub const IdentIndex = u32;
pub const ConstIndex = u32;

pub const DataPool = struct {
    const Tag = enum(u3) { int, string };
    // const Value = ConstIndex;

    identifiers: set.IndexedSet([]const u8),
    int_pool: set.IndexedSet(value.Value),

    pub fn init(allocator: std.mem.Allocator) DataPool {
        return .{
            .identifiers = set.IndexedSet([]const u8).init(allocator),
            .int_pool = set.IndexedSet(value.Value).init(allocator),
        };
    }

    pub fn deinit(self: *DataPool) void {
        self.identifiers.deinit();
        self.int_pool.deinit();
    }

    pub fn addIdent(self: *DataPool, id: []const u8) !IdentIndex {
        return try self.identifiers.insert(id);
    }

    pub fn addInt(self: *DataPool, val: i32) !ConstIndex {
        return try self.int_pool.insert(.{
            .tag = .int,
            .data = .{
                .int = val,
            },
        });
    }

    pub fn getIdentifier(self: *DataPool, index: IdentIndex) []const u8 {
        return self.identifiers.get(index);
    }

    pub fn getInt(self: *DataPool, index: ConstIndex) value.Value {
        return self.int_pool.get(index);
    }
};
