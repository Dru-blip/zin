const std = @import("std");
const Token = @import("lexer.zig").Token;

const Index = u24;
const TokenIndex = u24;

pub const Tag = enum(u8) {
    binop,
    uop,
    int,
};

const SyntaxError = error{
    UnexpectedToken,
    UnexpectedEndOfFile,
};

pub const Node = struct {
    data: Data,
    tag: Tag,
    token: TokenIndex,
    pub const index: Index = undefined;

    pub const Data = union(Tag) {
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

    pub fn init() !Ast {
        return .{
            .nodes = std.MultiArrayList(Node){},
        };
    }

    pub fn deinit(
        self: *Ast,
        allocator: std.mem.Allocator,
    ) void {
        self.nodes.deinit(allocator);
    }

    /// append the given node to the array and return its index
    pub fn append(
        self: *Ast,
        allocator: std.mem.Allocator,
        data: Node.Data,
        tag: Tag,
        token: TokenIndex,
    ) !Index {
        try self.nodes.append(allocator, .{
            .data = data,
            .tag = tag,
            .token = token,
        });
        const length: usize = self.nodes.len - 1;
        return @truncate(length);
    }
};

pub const Parser = struct {
    ast: Ast,
    tokens: *std.ArrayList(Token),
    position: TokenIndex,
    source: [:0]const u8,
    allocator: std.mem.Allocator,

    /// initialize a new parser with allocator
    pub fn init(
        allocator: std.mem.Allocator,
        source: [:0]const u8,
        tokens: *std.ArrayList(Token),
    ) !Parser {
        return .{
            .tokens = tokens,
            .source = source,
            .ast = try Ast.init(),
            .allocator = allocator,
            .position = 0,
        };
    }

    /// deallocate memory for ast nodes
    pub fn deinit(
        self: *Parser,
        allocator: std.mem.Allocator,
    ) void {
        self.ast.deinit(allocator);
    }

    /// print the flattened AST
    pub fn printAst(self: *Parser) void {
        var i: usize = 0;
        while (self.ast.nodes.len > i) : (i += 1) {
            const node = self.ast.nodes.get(i);
            std.log.info("ast {}: {}", .{ i, node.tag });
        }
    }

    /// top level parse function
    pub fn parse(self: *Parser) !void {
        // parse until eof token is hit
        while (self.tokens.items[self.position].tag != .eof) {
            // parse expression and catch error
            _ = self.parseExpr() catch |err| {
                // print error message
                std.log.err("{}", .{err});
                const tok = self.tokens.items[self.position];
                std.log.info("{}", .{tok.tag});
                self.position += 1;
            };
        }
    }

    /// parse expression
    fn parseExpr(self: *Parser) !Index {
        return self.parseInt();
    }

    /// parse integer token
    fn parseInt(self: *Parser) !Index {
        // get the current token
        const token = self.tokens.items[self.position];
        // if token is not an integer, return unexpected token error
        if (token.tag != .integer) return SyntaxError.UnexpectedToken;

        // parse the source literal to integer
        const value = try std.fmt.parseInt(i32, self.source[token.start..token.end], 10);
        // append the integer node to the ast array
        const index = try self.ast.append(
            self.allocator,
            .{ .int = .{ .value = value } },
            .int,
            self.position,
        );
        // move to the next token
        self.position += 1;
        // return the index of the integer node
        return index;
    }
};
