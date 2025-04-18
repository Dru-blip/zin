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
    const module = self.tree.nodes.get(self.tree.root.?);
    const total_stmts = module.rhs.?;
    const start_pos: u32 = module.offset.?;
    var i: u32 = 0;
    var index: ?u32 = start_pos + i;
    while (i < total_stmts and index != null) {
        const node = self.tree.nodes.get(@as(usize, index.?));
        switch (node.tag) {
            .var_decl,
            .expr_stmt,
            .block,
            => {
                try self.compileStmt(node);
                index = node.next_stmt;
            },
            else => {
                std.debug.print("Unexpected node type: {}\n", .{node.tag});
                std.process.exit(1);
            },
        }
        i += 1;
    }

    try self.unit.addOpcode(.halt);
}

fn compileStmt(self: *Compiler, node: Node) Errors!void {
    return switch (node.tag) {
        .block => try self.compileBlock(node),
        .expr_stmt => try self.compileExprStmt(node),
        .var_decl => try self.compileVarDecl(node),
        else => {
            std.debug.print("Unexpected node type: {}\n", .{self.pos});
            std.process.exit(1);
        },
    };
}

fn compileBlock(self: *Compiler, node: Node) !void {
    const total_stmts = node.rhs.?;
    const start_pos = node.offset.?;

    var i: u32 = 0;
    const index: ?u32 = start_pos + i;
    var next_stmt: ?u32 = index;
    while (i < total_stmts and next_stmt != null) {
        const stmt = self.tree.nodes.get(@as(usize, next_stmt.?));
        try self.compileStmt(stmt);
        next_stmt = stmt.next_stmt;
        i += 1;
    }
}

fn compileVarDecl(self: *Compiler, node: Node) !void {
    try self.compileExpr(node.rhs.?);
    try self.unit.addOpcode(.store);
    const bytes = try splitIntoBytes(node.lhs.?);
    try self.unit.add(bytes);
}

fn compileExprStmt(self: *Compiler, node: Node) !void {
    // std.debug.print("{} {}\n", .{ node.id, node.tag });
    return try self.compileExpr(node.lhs.?);
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
        const bytes = try splitIntoBytes(self.tree.extra.items[target.lhs.?]);
        try self.unit.add(bytes);
    }
}

fn emitBinOp(self: *Compiler, node: Node) !void {
    try self.compileExpr(node.lhs.?);
    try self.compileExpr(node.rhs.?);
    try self.unit.addOpcode(Opcode.tokenToOpcode(self.tokens.items[node.token].tag));
}

fn emitGetId(self: *Compiler, node: Node) !void {
    try self.unit.addOpcode(.get);
    const ind = self.tree.extra.items[node.lhs.?];
    // std.debug.print("{}\n", .{ind});
    const bytes = try splitIntoBytes(ind);
    try self.unit.add(bytes);
}

/// Emit a load integer instruction,
/// along with index of int literal.
fn emitLoadInt(self: *Compiler, node: Node) !void {
    try self.unit.addOpcode(.load_i);
    const ind = self.tree.extra.items[node.lhs.?];
    // std.debug.print("{}\n", .{ind});
    const bytes = try splitIntoBytes(ind);
    try self.unit.add(bytes);
}
