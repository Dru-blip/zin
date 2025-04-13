const std = @import("std");
const Token = @import("lexer.zig").Token;

pub const Index = u24;
pub const TokenIndex = u24;
pub const ExprIndex = u24;

pub const Tag = enum(u8) {
    var_decl,
    binop,
    uop,
    int,
};

pub const Node = struct {
    data: Data,
    tag: Tag,
    token: TokenIndex,
    pub const index: Index = undefined;

    pub const Data = union(Tag) {
        var_decl: struct {
            init: ExprIndex,
        },
        binop: struct {
            lhs: ExprIndex,
            rhs: ExprIndex,
        },
        uop: struct {
            lhs: ExprIndex,
        },
        int: struct {
            value: i32,
        },
    };
};

pub const Ast = struct {
    nodes: std.MultiArrayList(Node),
    expr_pool: std.MultiArrayList(Node),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !Ast {
        return .{
            .nodes = std.MultiArrayList(Node){},
            .expr_pool = std.MultiArrayList(Node){},
            .allocator = allocator,
        };
    }

    pub fn deinit(
        self: *Ast,
    ) void {
        self.nodes.deinit(self.allocator);
        self.expr_pool.deinit(self.allocator);
    }

    /// print the flattened AST
    pub fn printAst(self: *Ast) void {
        var i: usize = 0;
        while (self.nodes.len > i) : (i += 1) {
            const node = self.nodes.get(i);
            std.log.info("ast {}: {} {}", .{ i, node.tag, node.data });
        }
    }

    /// append the given node to the array and return its index
    pub fn append(
        self: *Ast,
        data: Node.Data,
        tag: Tag,
        token: TokenIndex,
    ) !Index {
        try self.nodes.append(self.allocator, .{
            .data = data,
            .tag = tag,
            .token = token,
        });
        const length: usize = self.nodes.len - 1;
        return @truncate(length);
    }

    pub fn addExpr(
        self: *Ast,
        data: Node.Data,
        tag: Tag,
        token: TokenIndex,
    ) !ExprIndex {
        try self.expr_pool.append(self.allocator, .{
            .data = data,
            .tag = tag,
            .token = token,
        });

        const length: usize = self.expr_pool.len - 1;
        return @truncate(length);
    }
};
