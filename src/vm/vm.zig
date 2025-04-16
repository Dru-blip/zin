const std = @import("std");

const value = @import("../value.zig");
const symbol_table = @import("../symbol_table.zig");

const unit = @import("../bytecode/unit.zig");
const SymbolTable = symbol_table.SymbolTable;

pub const VM = struct {
    ip: u32,
    stack: std.ArrayList(value.Value),
    arena: std.heap.ArenaAllocator,
    globals: SymbolTable,
    module: *unit.Unit,

    pub fn init(allocator: std.mem.Allocator, module: *unit.Unit) VM {
        const arena = std.heap.ArenaAllocator.init(allocator);

        return .{
            .ip = 0,
            .stack = std.ArrayList(value.Value).init(allocator),
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
            const op: unit.Opcode = @enumFromInt(self.module.code.items[self.ip]);
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
                else => {
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
};
