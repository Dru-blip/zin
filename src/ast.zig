const std = @import("std");
const DataPool = @import("DataPool.zig");
const Token = @import("lexer.zig").Token;

const IdentIndex = DataPool.IdentIndex;
const ConstIndex = DataPool.ConstIndex;

pub const NodeIndex = u32;
pub const ExtraIndex = u32;
pub const TokenIndex = u32;

pub const Tag = enum(u8) {
    var_decl,
    expr_stmt,
    assign,
    binop,
    uop,
    int,
    id,
};

const Ast = @This();

pub const Node = struct {
    tag: Tag,
    token: TokenIndex,
    lhs: ?ExtraIndex,
    rhs: ?ExtraIndex,
};

nodes: std.MultiArrayList(Node),
extra: std.ArrayList(ExtraIndex),
gpa: std.mem.Allocator,
tokens: *std.ArrayList(Token),
root: ?NodeIndex,

pub fn init(gpa: std.mem.Allocator, tokens: *std.ArrayList(Token)) !Ast {
    return .{
        .nodes = std.MultiArrayList(Node){},
        .extra = std.ArrayList(ExtraIndex).init(gpa),
        .gpa = gpa,
        .tokens = tokens,
        .root = null,
    };
}

pub fn deinit(
    self: *Ast,
) void {
    self.nodes.deinit(self.gpa);
    self.extra.deinit();
}

/// append the given node to the array and return its index
pub fn append(
    self: *Ast,
    tag: Tag,
    token: TokenIndex,
    lhs: ?ExtraIndex,
    rhs: ?ExtraIndex,
) !NodeIndex {
    try self.nodes.append(self.gpa, .{
        .tag = tag,
        .token = token,
        .lhs = lhs,
        .rhs = rhs,
    });
    const length: usize = self.nodes.len - 1;
    return @truncate(length);
}

pub fn printAst(self: *Ast) void {
    for (self.nodes.items(.tag)) |tag| {
        std.debug.print("{}\n", .{tag});
    }
}

// fn printIndent(indent: u32) void {
//     var i: u32 = 0;
//     while (i < indent) : (i += 1) {
//         std.debug.print("  ", .{});
//     }
// }

// fn printNode(self: *Ast, index: u32, indent: u32) void {
//     const node = self.nodes.get(index);
//     // printIndent(indent);
//     switch (node.tag) {
//         .var_decl => std.debug.print("var_decl", .{}),
//         .expr_stmt => {
//             std.debug.print("expr_stmt[ ", .{});
//             self.printNode(node.lhs.?, indent);
//             std.debug.print("]\n", .{});
//         },
//         .assign => {
//             std.debug.print("assign[", .{});
//             self.printNode(node.lhs.?, indent);
//             std.debug.print(" = ", .{});
//             self.printNode(node.rhs.?, indent);
//             std.debug.print("]", .{});
//         },
//         .binop => std.debug.print("binop", .{}),
//         .uop => std.debug.print("uop", .{}),
//         .int => {
//             std.debug.print("{}", .{node.data.?.int});
//         },
//         .id => {
//             std.debug.print("{}", .{node.data.?.id});
//         },
//     }
// }
