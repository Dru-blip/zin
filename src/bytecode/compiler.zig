const std = @import("std");

const unit = @import("./unit.zig");
const ast = @import("../ast.zig");
const pool = @import("../pool.zig");
const Ast = ast.Ast;
const Index = ast.Index;
const Node = ast.Node;
const TokenIndex = ast.TokenIndex;
const Token = @import("../lexer.zig").Token;

pub const Compiler = struct {
    tree: *Ast,
    position: Index,
    unit: unit.Unit,
    tokens: *std.ArrayList(Token),

    pub fn init(
        allocator: std.mem.Allocator,
        tree: *Ast,
        data_pool: *pool.DataPool,
        tokens: *std.ArrayList(Token),
    ) Compiler {
        return .{
            .tree = tree,
            .position = 0,
            .unit = try unit.Unit.init(allocator, data_pool),
            .tokens = tokens,
        };
    }

    pub fn deinit(self: *Compiler) void {
        self.unit.deinit();
    }

    /// splits the given u32 into 4 u8 in little endian format
    inline fn splitIntoBytes(value: u32) ![]const u8 {
        var bytes = [4]u8{ 0, 0, 0, 0 };
        bytes[0] = @intCast(value & 0xFF);
        bytes[1] = @intCast((value >> 8) & 0xFF);
        bytes[2] = @intCast((value >> 16) & 0xFF);
        bytes[3] = @intCast((value >> 24) & 0xFF);
        return &bytes;
    }

    pub fn compile(self: *Compiler) !void {
        try self.emit();
    }

    fn emit(self: *Compiler) !void {
        for (
            self.tree.nodes.items(.token),
            self.tree.nodes.items(.tag),
            self.tree.nodes.items(.data),
        ) |
            token,
            tag,
            data,
        | {
            switch (tag) {
                .var_decl => try self.emitVarDecl(data),
                .binop => try self.emitBinOp(token),
                .int => try self.emitLoadInt(data),
                else => {},
            }
        }
    }

    fn emitVarDecl(self: *Compiler, data: Node.Data) !void {
        try self.unit.addOpcode(.store);
        const bytes = try splitIntoBytes(data.var_decl.name);
        try self.unit.add(bytes);
    }

    fn emitBinOp(self: *Compiler, token: TokenIndex) !void {
        const operator = self.tokens.items[token].tag;
        try self.unit.addOpcode(unit.Opcode.tokenToOpcode(operator));
    }

    /// Emit a load integer instruction,
    /// along with index of int literal.
    fn emitLoadInt(self: *Compiler, data: Node.Data) !void {
        try self.unit.addOpcode(.load_i);
        const bytes = try splitIntoBytes(data.int);
        try self.unit.add(bytes);
    }
};
