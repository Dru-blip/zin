const std = @import("std");

const pool = @import("../pool.zig");
const unit_m = @import("unit.zig");
const Opcode = unit_m.Opcode;

pub const Disassembler = struct {
    unit: *unit_m.Unit,
    data_pool: *pool.DataPool,
    ip: u32,

    pub fn init(data_pool: *pool.DataPool, unit: *unit_m.Unit) Disassembler {
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
        while (self.ip < self.unit.code.items.len) {
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
                else => {
                    std.debug.print("Unknown opcode: {}\n", .{tag});
                },
            }
        }
    }
};
