const std = @import("std");
const Token = @import("lexer.zig").Token;

pub const Index = u24;
pub const TokenIndex = u24;
pub const FragmentIndex = u24;

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
            init: Index,
        },
        binop: struct {
            lhs: Index,
            rhs: Index,
        },
        uop: struct {
            lhs: Index,
        },
        int: struct {
            value: i32,
        },
    };
};

pub const Ast = struct {
    nodes: std.MultiArrayList(Node),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !Ast {
        return .{
            .nodes = std.MultiArrayList(Node){},
            .allocator = allocator,
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
