const std = @import("std");

const Unit = @import("./unit.zig");
const Ast = @import("../ast.zig");
const DataPool = @import("../DataPool.zig");
const Index = Ast.Index;
const Node = Ast.Node;
const TokenIndex = Ast.TokenIndex;
const Token = @import("../lexer.zig").Token;

const Errors = (std.mem.Allocator.Error || std.fmt.ParseIntError);

const Opcode = Unit.Opcode;

tree: *Ast,
position: u32,
unit: Unit,
tokens: *std.ArrayList(Token),
pos: usize,

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
        .pos = 0,
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
    while (self.pos < self.tree.nodes.len) {
        const node = self.tree.nodes.get(self.pos);
        switch (node.tag) {
            .var_decl => try self.compileVarDecl(node),
            // .assign => try self.emitAssign(data),
            // .binop => try self.emitBinOp(node.token),
            .expr_stmt => try self.compileExprStmt(node),
            else => {
                break;
            },
        }
    }

    try self.unit.addOpcode(.halt);
}

fn compileVarDecl(self: *Compiler, node: Node) !void {
    self.pos += 1;
    try self.compileExpr(node.rhs.?);
    try self.unit.addOpcode(.store);
    const bytes = try splitIntoBytes(node.lhs.?);
    try self.unit.add(bytes);
}

fn compileExprStmt(self: *Compiler, node: Node) !void {
    // std.debug.print("{} {}\n", .{ node.id, node.tag });
    self.pos += 1;
    try self.compileExpr(node.lhs.?);
    // try self.unit.addOpcode(.expr_stmt);
    // const bytes = try splitIntoBytes(node.expr_stmt.expr);
    // try self.unit.add(bytes);
}

fn compileExpr(self: *Compiler, index: u32) Errors!void {
    const node = self.tree.nodes.get(index);

    switch (node.tag) {
        .assign => {
            try self.emitAssign(node);
        },
        .binop => {
            try self.emitBinOp(node);
        },
        .int => {
            try self.emitLoadInt(node);
        },
        .id => {
            try self.emitGetId(node);
        },
        else => {},
    }
}

fn emitAssign(self: *Compiler, node: Node) !void {
    try self.compileExpr(node.rhs.?);
    const target = self.tree.nodes.get(node.lhs.?);

    if (target.tag == .id) {
        try self.unit.addOpcode(.store);
        const bytes = try splitIntoBytes(target.lhs.?);
        try self.unit.add(bytes);
    }

    self.pos += 2;
}

fn emitBinOp(self: *Compiler, node: Node) !void {
    try self.compileExpr(node.lhs.?);
    try self.compileExpr(node.rhs.?);
    try self.unit.addOpcode(Opcode.tokenToOpcode(self.tokens.items[node.token].tag));
    self.pos += 3;
}

fn emitGetId(self: *Compiler, node: Node) !void {
    try self.unit.addOpcode(.get);
    const ind = self.tree.extra.items[node.lhs.?];
    // std.debug.print("{}\n", .{ind});
    const bytes = try splitIntoBytes(ind);
    try self.unit.add(bytes);
    self.pos += 1;
}

/// Emit a load integer instruction,
/// along with index of int literal.
fn emitLoadInt(self: *Compiler, node: Node) !void {
    try self.unit.addOpcode(.load_i);
    const ind = self.tree.extra.items[node.lhs.?];
    // std.debug.print("{}\n", .{ind});
    const bytes = try splitIntoBytes(ind);
    try self.unit.add(bytes);
    self.pos += 1;
}
