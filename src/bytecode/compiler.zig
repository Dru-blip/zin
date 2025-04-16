const std = @import("std");

const Unit = @import("./unit.zig");
const Ast = @import("../ast.zig");
const DataPool = @import("../DataPool.zig");
const Index = Ast.Index;
const Node = Ast.Node;
const TokenIndex = Ast.TokenIndex;
const Token = @import("../lexer.zig").Token;

const Opcode = Unit.Opcode;

tree: *Ast,
position: Index,
unit: Unit,
tokens: *std.ArrayList(Token),

const Compiler = @This();

pub fn init(
    allocator: std.mem.Allocator,
    tree: *Ast,
    data_pool: *DataPool,
    tokens: *std.ArrayList(Token),
) Compiler {
    return .{
        .tree = tree,
        .position = 0,
        .unit = try Unit.init(allocator, data_pool),
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
            .id => try self.emitGetId(data),
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
    try self.unit.addOpcode(Opcode.tokenToOpcode(operator));
}

fn emitGetId(self: *Compiler, data: Node.Data) !void {
    try self.unit.addOpcode(.get);
    const bytes = try splitIntoBytes(data.id);
    try self.unit.add(bytes);
}

/// Emit a load integer instruction,
/// along with index of int literal.
fn emitLoadInt(self: *Compiler, data: Node.Data) !void {
    try self.unit.addOpcode(.load_i);
    const bytes = try splitIntoBytes(data.int);
    try self.unit.add(bytes);
}
