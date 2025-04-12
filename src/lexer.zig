const std = @import("std");

pub const Token = struct {
    pub const Tag = enum(u8) {
        keyword_if,
        keyword_and,
        keyword_or,
        keyword_var,
        keyword_else,
        keyword_def,
        keyword_struct,
        keyword_for,
        keyword_nil,
        keyword_true,
        keyword_false,

        integer,
        float,
        string,

        // punctuations
        left_paren,
        right_paren,
        left_brace,
        right_brace,
        comma,
        dot,
        semicolon,

        // operators
        minus,
        plus,
        slash,
        asterisk,
        bang,
        equal,
        equal_equal,
        bang_equal,
        angle_bracket_left,
        angle_bracket_right,
        angle_bracket_left_equal,
        angle_bracket_right_equal,

        // misc
        range,
        invalid,
        eof,
    };

    pub const keywords = std.StaticStringMap(Tag).initComptime(.{
        .{ "if", Tag.keyword_if },
        .{ "and", Tag.keyword_and },
        .{ "or", Tag.keyword_or },
        .{ "var", Tag.keyword_var },
        .{ "else", Tag.keyword_else },
        .{ "def", Tag.keyword_def },
        .{ "struct", Tag.keyword_struct },
        .{ "for", Tag.keyword_for },
        .{ "nil", Tag.keyword_nil },
        .{ "true", Tag.keyword_true },
        .{ "false", Tag.keyword_false },
    });

    start: u32,
    end: u32,
    line: u32,
    col: u32,
    tag: Tag,

    fn getKeyword(keyword: []const u8) ?Tag {
        return keywords.get(keyword);
    }
};

pub const Lexer = struct {
    input: [:0]const u8,
    line: u32 = 1,
    col: u32 = 0,
    position: u32,
    tokens: std.ArrayList(Token),

    const State = enum {
        start,
        integer,
        // string,

        // plus,
        // minus,
        // star,
        // asterisk,
        // bang,
        // equal,
        // angle_bracket_left,
        // angle_bracket_right,
        // dot,
    };

    pub fn init(allocator: std.mem.Allocator, input: [:0]const u8) Lexer {
        return .{
            .input = input,
            .position = 0,
            .tokens = std.ArrayList(Token).init(allocator),
        };
    }

    pub fn dealloc(self: *Lexer) void {
        self.tokens.deinit();
    }

    /// checking if source is avaliable to scan
    fn isNext(self: *Lexer) bool {
        return self.position <= self.input.len;
    }

    fn next(self: *Lexer) Token {
        var token: Token = .{
            .tag = undefined,
            .start = self.position,
            .end = self.position + 1,
            .line = self.line,
            .col = self.col,
        };

        state: switch (State.start) {
            .start => {
                switch (self.input[self.position]) {
                    0 => {
                        if (self.position == self.input.len) {
                            self.position += 1;
                            token.tag = .eof;
                            return token;
                        }
                    },
                    ' ', '\t', '\r' => {
                        self.position += 1;
                        self.col += 1;
                        continue :state .start;
                    },
                    '\n' => {
                        self.line += 1;
                        self.col = 0;
                        self.position += 1;
                        continue :state .start;
                    },
                    '0'...'9' => {
                        token.tag = .integer;
                        self.position += 1;
                        self.col += 1;
                        continue :state .integer;
                    },
                    '(' => {
                        self.position += 1;
                        self.col += 1;
                        token.tag = .left_paren;
                    },
                    ')' => {
                        self.position += 1;
                        self.col += 1;
                        token.tag = .right_paren;
                    },
                    '{' => {
                        self.position += 1;
                        self.col += 1;
                        token.tag = .left_brace;
                    },
                    '}' => {
                        self.position += 1;
                        self.col += 1;
                        token.tag = .right_brace;
                    },
                    '+' => {
                        self.position += 1;
                        self.col += 1;
                        token.tag = .plus;
                    },
                    '-' => {
                        self.position += 1;
                        self.col += 1;
                        token.tag = .minus;
                    },
                    '*' => {
                        self.position += 1;
                        self.col += 1;
                        token.tag = .asterisk;
                    },
                    '/' => {
                        self.position += 1;
                        self.col += 1;
                        token.tag = .slash;
                    },
                    else => {
                        token.end = self.position;
                        token.tag = .invalid;
                        return token;
                    },
                }
            },
            // .plus => {

            // },
            .integer => {
                switch (self.input[self.position]) {
                    '0'...'9' => {
                        self.position += 1;
                        self.col += 1;
                        continue :state .integer;
                    },
                    else => {},
                }
            },
        }

        return token;
    }

    pub fn tokenize(self: *Lexer) !void {
        while (self.isNext()) {
            const token = self.next();
            try self.tokens.append(token);
        }
    }
};

test "punctuations" {
    try testLexer("{}()", &.{
        .left_brace,
        .right_brace,
        .left_paren,
        .right_paren,
    });
}

test "integers" {
    try testLexer("563", &.{.integer});
}

fn testLexer(source: [:0]const u8, expectedTags: []const Token.Tag) !void {
    var lexer: Lexer = Lexer.init(std.testing.allocator, source);

    for (expectedTags) |tag| {
        const tok = lexer.next();
        try std.testing.expectEqual(tag, tok.tag);
    }
    try lexer.dealloc();
}
