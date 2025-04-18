const std = @import("std");

const DataPool = @import("../DataPool.zig");
const Unit = @import("unit.zig");
const Opcode = Unit.Opcode;

const Disassembler = @This();

unit: *Unit,
data_pool: *DataPool,
ip: u32,

pub fn init(data_pool: *DataPool, unit: *Unit) Disassembler {
    return .{
        .data_pool = data_pool,
        .unit = unit,
        .ip = 0,
    };
}

/// combines 4 u8 into a u32 from little-endian byte order
inline fn combineBytes(value: []const u8) u32 {
    return @as(u32, value[3]) << 24 | @as(u32, value[2]) << 16 | @as(u32, value[1]) << 8 | @as(u32, value[0]);
}

pub fn disassemble(self: *Disassembler) !void {
    const writer = std.io.getStdOut().writer();
    var stop: bool = false;
    while (self.ip < self.unit.code.items.len and !stop) {
        const value = self.unit.code.items[self.ip];
        const tag: Opcode = @enumFromInt(value);
        switch (tag) {
            .load_i => {
                const bytes = self.unit.code.items[self.ip + 1 .. self.ip + 5];
                const index = combineBytes(bytes);
                try writer.print("0x{x:0>4} 0x{x:0>4}  load_i {}  [{}]\n", .{
                    value,
                    index,
                    index,
                    self.data_pool.getInt(index).data.int,
                });
                self.ip += 5;
            },
            .store => {
                const bytes = self.unit.code.items[self.ip + 1 .. self.ip + 5];
                const index = combineBytes(bytes);
                try writer.print("0x{x:0>4} 0x{x:0>4}  store {}  [{s}]\n", .{
                    value,
                    index,
                    index,
                    self.data_pool.getIdentifier(index),
                });
                self.ip += 5;
            },
            .get => {
                const bytes = self.unit.code.items[self.ip + 1 .. self.ip + 5];
                const index = combineBytes(bytes);
                try writer.print("0x{x:0>4} 0x{x:0>4}  get {}  [{s}]\n", .{
                    value,
                    index,
                    index,
                    self.data_pool.getIdentifier(index),
                });
                self.ip += 5;
            },
            .add => {
                try writer.print("0x{x:0>4} add\n", .{value});
                self.ip += 1;
            },
            .minus => {
                try writer.print("0x{x:0>4} minus\n", .{value});
                self.ip += 1;
            },
            .mul => {
                try writer.print("0x{x:0>4} mul\n", .{value});
                self.ip += 1;
            },
            .div => {
                try writer.print("0x{x:0>4} div\n", .{value});
                self.ip += 1;
            },
            .halt => {
                try writer.print("0x{x:0>4} halt\n", .{value});
                self.ip += 1;
                stop = true;
            },
            else => {
                std.debug.print("Unknown opcode: {}\n", .{tag});
                break;
            },
        }
    }
}
