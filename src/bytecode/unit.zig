const std = @import("std");
const DataPool = @import("../DataPool.zig");
const Value = @import("../Value.zig");
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
    modulus,
    less,
    greater,
    less_equal,
    greater_equal,
    equal,
    nq,
    halt,

    pub inline fn tokenToOpcode(tag: Tag) Opcode {
        return switch (tag) {
            .plus => Opcode.add,
            .minus => Opcode.minus,
            .asterisk => Opcode.mul,
            .slash => Opcode.div,
            .modulus => Opcode.modulus,
            .angle_bracket_left => Opcode.less,
            .angle_bracket_right => Opcode.greater,
            .angle_bracket_left_equal => Opcode.less_equal,
            .angle_bracket_right_equal => Opcode.greater_equal,
            .equal => Opcode.store,
            .bang_equal => Opcode.nq,
            .equal_equal => Opcode.equal,
            else => unreachable,
        };
    }
};

data_pool: *DataPool,
code: std.ArrayList(u8),

const Unit = @This();

pub fn init(
    allocator: std.mem.Allocator,
    data_pool: *DataPool,
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
