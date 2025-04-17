const std = @import("std");
const Value = @import("../Value.zig");
const SymbolTable = @import("../symbol_table.zig");
const Unit = @import("../bytecode/unit.zig");

ip: u32,
stack: std.ArrayList(Value),
arena: std.heap.ArenaAllocator,
globals: SymbolTable,
module: *Unit,

const VM = @This();

pub fn init(allocator: std.mem.Allocator, module: *Unit) VM {
    const arena = std.heap.ArenaAllocator.init(allocator);

    return .{
        .ip = 0,
        .stack = std.ArrayList(Value).init(allocator),
        .arena = arena,
        .globals = SymbolTable.init(allocator),
        .module = module,
    };
}

pub fn deinit(self: *VM) void {
    self.stack.deinit();
    self.arena.deinit();
    self.globals.deinit();
}

fn readNext4Bytes(self: *VM) u32 {
    const bytes = self.module.code.items[self.ip .. self.ip + 4];
    self.ip += 4;
    return @as(u32, bytes[3]) << 24 | @as(u32, bytes[2]) << 16 | @as(u32, bytes[1]) << 8 | @as(u32, bytes[0]);
}

pub fn run(self: *VM) !void {
    while (self.ip < self.module.code.items.len) {
        const op: Unit.Opcode = @enumFromInt(self.module.code.items[self.ip]);
        switch (op) {
            .load_i => {
                try self.opLoadInt();
            },
            .store => {
                self.ip += 1;
                const index = self.readNext4Bytes();
                const key = self.module.data_pool.getIdentifier(index);
                const val = self.stack.pop();
                try self.globals.insert(key, val.?);
            },
            .get => {
                self.ip += 1;
                const index = self.readNext4Bytes();
                const key = self.module.data_pool.getIdentifier(index);
                const val = self.globals.lookup(key);
                try self.stack.append(val.?);
            },
            .add => {
                const a = self.stack.pop();
                const b = self.stack.pop();
                self.ip += 1;
                try self.stack.append(.{
                    .tag = .int,
                    .data = .{
                        .int = a.?.data.int + b.?.data.int,
                    },
                });
            },
            .minus => {
                const a = self.stack.pop();
                const b = self.stack.pop();
                self.ip += 1;
                try self.stack.append(.{
                    .tag = .int,
                    .data = .{
                        .int = a.?.data.int - b.?.data.int,
                    },
                });
            },
            .mul => {
                const a = self.stack.pop();
                const b = self.stack.pop();
                self.ip += 1;
                try self.stack.append(.{
                    .tag = .int,
                    .data = .{
                        .int = a.?.data.int * b.?.data.int,
                    },
                });
            },
            .div => {
                const a = self.stack.pop();
                const b = self.stack.pop();
                self.ip += 1;
                try self.stack.append(.{
                    .tag = .int,
                    .data = .{
                        .int = @divTrunc(a.?.data.int, b.?.data.int),
                    },
                });
            },
            .modulus => {
                const a = self.stack.pop();
                const b = self.stack.pop();
                self.ip += 1;
                try self.stack.append(.{
                    .tag = .int,
                    .data = .{
                        .int = @mod(a.?.data.int, b.?.data.int),
                    },
                });
            },
            .equal => {
                const a = self.stack.pop();
                const b = self.stack.pop();
                self.ip += 1;
                try self.stack.append(.{
                    .tag = .bool,
                    .data = .{
                        .bool = a.?.data.int == b.?.data.int,
                    },
                });
            },
            .greater => {
                const a = self.stack.pop();
                const b = self.stack.pop();
                self.ip += 1;
                try self.stack.append(.{
                    .tag = .bool,
                    .data = .{
                        .bool = a.?.data.int > b.?.data.int,
                    },
                });
            },
            .less => {
                const a = self.stack.pop();
                const b = self.stack.pop();
                self.ip += 1;
                try self.stack.append(.{
                    .tag = .bool,
                    .data = .{
                        .bool = a.?.data.int < b.?.data.int,
                    },
                });
            },
            .nq => {
                const a = self.stack.pop();
                const b = self.stack.pop();
                self.ip += 1;
                try self.stack.append(.{
                    .tag = .bool,
                    .data = .{
                        .bool = a.?.data.int != b.?.data.int,
                    },
                });
            },
            .halt => {
                break;
            },
            else => {
                std.debug.print("unknown opcode: {}\n", .{op});
                break;
            },
        }
    }
}

inline fn opLoadInt(self: *VM) !void {
    self.ip += 1;
    const index = self.readNext4Bytes();
    const val = try self.module.getInt(index);

    try self.stack.append(val);
}
