const std = @import("std");
const Value = @import("value.zig").Value;

pub const SymbolTable = struct {
    table: std.StringHashMap(Value),

    pub fn init(allocator: std.mem.Allocator) SymbolTable {
        return .{
            .table = std.StringHashMap(Value).init(allocator),
        };
    }

    pub fn deinit(self: *SymbolTable) void {
        self.table.deinit();
    }

    pub fn insert(self: *SymbolTable, key: []const u8, value: Value) !void {
        try self.table.put(key, value);
    }

    pub fn lookup(self: *SymbolTable, key: []const u8) ?Value {
        return self.table.get(key);
    }
};
