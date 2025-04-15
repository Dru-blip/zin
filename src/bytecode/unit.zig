const std = @import("std");
const pool = @import("../pool.zig");
const Value = @import("../value.zig").Value;
const Tag = @import("../lexer.zig").Token.Tag;

// opcodes - u8 enum
pub const Opcode = enum(u8) {
    push,
    pop,
    load_i,
    load_c,
    store,
    get,
    add,
    minus,
    mul,
    div,

    pub inline fn tokenToOpcode(tag: Tag) Opcode {
        return switch (tag) {
            .plus => Opcode.add,
            .minus => Opcode.minus,
            .asterisk => Opcode.mul,
            .slash => Opcode.div,
            else => unreachable,
        };
    }
};

/// structure for storing a module's bytecode information
pub const Unit = struct {
    data_pool: *pool.DataPool,
    code: std.ArrayList(u8),

    pub fn init(
        allocator: std.mem.Allocator,
        data_pool: *pool.DataPool,
    ) !Unit {
        return .{
            .data_pool = data_pool,
            .code = std.ArrayList(u8).init(allocator),
        };
    }

    pub fn deinit(self: *Unit) void {
        self.code.deinit();
    }

    pub fn addOpcode(self: *Unit, opcode: Opcode) !void {
        try self.code.append(@intFromEnum(opcode));
    }

    pub fn add(self: *Unit, value: []const u8) !void {
        try self.code.appendSlice(value);
    }

    pub fn getInt(self: *Unit, index: u32) !Value {
        return self.data_pool.getInt(index);
    }
};
