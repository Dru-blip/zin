const std = @import("std");
const pool = @import("pool.zig");

const Token = @import("lexer.zig").Token;

const IdentIndex = pool.IdentIndex;
const ConstIndex = pool.ConstIndex;

pub const Index = u24;
pub const TokenIndex = u24;

pub const Tag = enum(u8) {
    var_decl,
    binop,
    uop,
    int,
    id,
};

pub const Node = struct {
    data: Data,
    tag: Tag,
    token: TokenIndex,
    pub const index: Index = undefined;

    pub const Data = union(Tag) {
        var_decl: struct {
            name: IdentIndex,
            init: Index,
        },
        binop: struct {
            lhs: Index,
            rhs: Index,
        },
        uop: struct {
            lhs: Index,
        },
        int: ConstIndex,
        id: IdentIndex,
    };
};

pub const Ast = struct {
    nodes: std.MultiArrayList(Node),
    allocator: std.mem.Allocator,
    tokens: *std.ArrayList(Token),

    pub fn init(allocator: std.mem.Allocator, tokens: *std.ArrayList(Token)) !Ast {
        return .{
            .nodes = std.MultiArrayList(Node){},
            .allocator = allocator,
            .tokens = tokens,
        };
    }

    pub fn deinit(
        self: *Ast,
    ) void {
        self.nodes.deinit(self.allocator);
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
};
