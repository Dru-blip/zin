const std = @import("std");
const DataPool = @import("DataPool.zig");
const Token = @import("lexer.zig").Token;

const IdentIndex = DataPool.IdentIndex;
const ConstIndex = DataPool.ConstIndex;

pub const Index = u24;
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
    data: ?Data,
    tag: Tag,
    token: TokenIndex,

    lhs: ?ExtraIndex,
    rhs: ?ExtraIndex,

    pub const Data = union {
        op: TokenIndex,
        int: ConstIndex,
        id: IdentIndex,
    };
};

nodes: std.MultiArrayList(Node),
gpa: std.mem.Allocator,
tokens: *std.ArrayList(Token),
root: ?Index,

pub fn init(gpa: std.mem.Allocator, tokens: *std.ArrayList(Token)) !Ast {
    return .{
        .nodes = std.MultiArrayList(Node){},
        .gpa = gpa,
        .tokens = tokens,
        .root = null,
    };
}

pub fn deinit(
    self: *Ast,
) void {
    self.nodes.deinit(self.gpa);
}

/// append the given node to the array and return its index
pub fn append(
    self: *Ast,
    tag: Tag,
    token: TokenIndex,
    data: ?Node.Data,
    lhs: ?ExtraIndex,
    rhs: ?ExtraIndex,
) !Index {
    try self.nodes.append(self.gpa, .{
        .data = data,
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
