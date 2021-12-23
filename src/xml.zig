const std = @import("std");
const mem = std.mem;

pub const Parser = struct {
    document: []const u8,
    current_tag: []const u8 = undefined,
    char_buffer: [4]u8 = undefined,
    mode: enum { normal, attrs, chars, entity } = .normal,

    pub fn init(document: []const u8) Parser {
        return Parser{
            .document = document,
        };
    }

    pub fn next(p: *Parser) ?Event {
        return switch (p.mode) {
            .normal => p.nextNormal(),
            .attrs => p.nextAttrs(),
            .chars => p.nextChars(),
            .entity => p.nextEntity(),
        };
    }

    fn nextNormal(p: *Parser) ?Event {
        p.skipWhitespace();
        switch (p.peek(0) orelse return null) {
            '<' => switch (p.peek(1) orelse return null) {
                '?' => {
                    if (mem.indexOf(u8, p.document[2..], "?>")) |end| {
                        const ev = Event{ .processing_instruction = p.document[2 .. end + 2] };
                        p.document = p.document[end + 4 ..];
                        return ev;
                    }
                },
                '/' => switch (p.peek(2) orelse return null) {
                    ':', 'A'...'Z', '_', 'a'...'z' => {
                        if (mem.indexOfScalar(u8, p.document[3..], '>')) |end| {
                            const ev = Event{ .close_tag = p.document[2 .. end + 3] };
                            p.document = p.document[end + 4 ..];
                            return ev;
                        }
                    },
                    else => {},
                },
                '!' => switch (p.peek(2) orelse return null) {
                    '-' => if ((p.peek(3) orelse return null) == '-') {
                        if (mem.indexOf(u8, p.document[3..], "-->")) |end| {
                            const ev = Event{ .comment = p.document[4 .. end + 3] };
                            p.document = p.document[end + 6 ..];
                            return ev;
                        }
                    },
                    '[' => if (mem.startsWith(u8, p.document[3..], "CDATA[")) {
                        if (mem.indexOf(u8, p.document, "]]>")) |end| {
                            const ev = Event{ .character_data = p.document[9..end] };
                            p.document = p.document[end + 3 ..];
                            return ev;
                        }
                    },
                    else => {},
                },
                ':', 'A'...'Z', '_', 'a'...'z' => {
                    const angle = mem.indexOfScalar(u8, p.document, '>') orelse return null;
                    if (mem.indexOfScalar(u8, p.document[0..angle], ' ')) |space| {
                        const ev = Event{ .open_tag = p.document[1..space] };
                        p.current_tag = ev.open_tag;
                        p.document = p.document[space..];
                        p.mode = .attrs;
                        return ev;
                    }
                    if (mem.indexOfScalar(u8, p.document[0..angle], '/')) |slash| {
                        const ev = Event{ .open_tag = p.document[1..slash] };
                        p.current_tag = ev.open_tag;
                        p.document = p.document[slash..];
                        p.mode = .attrs;
                        return ev;
                    }
                    const ev = Event{ .open_tag = p.document[1..angle] };
                    p.current_tag = ev.open_tag;
                    p.document = p.document[angle..];
                    p.mode = .attrs;
                    return ev;
                },
                else => {},
            },
            else => {
                p.mode = .chars;
                return p.nextChars();
            },
        }
        return null;
    }

    fn nextAttrs(p: *Parser) ?Event {
        p.skipWhitespace();
        switch (p.peek(0) orelse return null) {
            '>' => {
                p.document = p.document[1..];
                p.mode = .normal;
                return p.nextNormal();
            },
            '/' => {
                const ev = Event{ .close_tag = p.current_tag };
                if ((p.peek(1) orelse return null) != '>')
                    return null;
                p.document = p.document[2..];
                p.mode = .normal;
                return ev;
            },
            else => {},
        }

        var i: usize = 0;
        while (isNameChar(p.peek(i) orelse return null)) : (i += 1) {}
        const name = p.document[0..i];

        p.document = p.document[i..];
        p.skipWhitespace();

        if ((p.peek(0) orelse return null) != '=')
            return null;

        p.document = p.document[1..];
        p.skipWhitespace();

        const c = p.peek(0) orelse return null;
        switch (c) {
            '\'', '"' => {
                if (mem.indexOfScalar(u8, p.document[1..], c)) |end| {
                    const ev = Event{
                        .attribute = .{
                            .name = name,
                            .raw_value = p.document[1 .. end + 1],
                        },
                    };
                    p.document = p.document[end + 2 ..];
                    return ev;
                }
            },
            else => {},
        }

        return null;
    }

    fn nextChars(p: *Parser) ?Event {
        var i: usize = 0;
        while (true) : (i += 1) {
            const c = p.peek(i) orelse return null;
            if (c == '<' or c == '&') {
                const ev = Event{ .character_data = p.document[0..i] };
                p.document = p.document[i..];
                p.mode = switch (c) {
                    '<' => .normal,
                    '&' => .entity,
                    else => unreachable,
                };
                return ev;
            }
            switch (c) {
                '<', '&' => {},
                else => {},
            }
        }
        return null;
    }

    fn parseEntity(s: []const u8, buf: *[4]u8) ?usize {
        const semi = mem.indexOfScalar(u8, s, ';') orelse return null;
        const entity = s[0..semi];
        if (mem.eql(u8, entity, "lt")) {
            buf.* = mem.toBytes(@as(u32, '<'));
        } else if (mem.eql(u8, entity, "gt")) {
            buf.* = mem.toBytes(@as(u32, '>'));
        } else if (mem.eql(u8, entity, "amp")) {
            buf.* = mem.toBytes(@as(u32, '&'));
        } else if (mem.eql(u8, entity, "apos")) {
            buf.* = mem.toBytes(@as(u32, '\''));
        } else if (mem.eql(u8, entity, "quot")) {
            buf.* = mem.toBytes(@as(u32, '"'));
        } else if (mem.startsWith(u8, entity, "#x")) {
            const codepoint = std.fmt.parseInt(u21, entity[2..semi], 16) catch return null;
            buf.* = mem.toBytes(@as(u32, codepoint));
        } else if (mem.startsWith(u8, entity, "#")) {
            const codepoint = std.fmt.parseInt(u21, entity[1..semi], 10) catch return null;
            buf.* = mem.toBytes(@as(u32, codepoint));
        } else {
            return null;
        }
        return semi;
    }

    fn nextEntity(p: *Parser) ?Event {
        if ((p.peek(0) orelse return null) != '&')
            return null;

        if (parseEntity(p.document[1..], &p.char_buffer)) |semi| {
            const codepoint = mem.bytesToValue(u32, &p.char_buffer);
            const n = std.unicode.utf8Encode(@intCast(u21, codepoint), &p.char_buffer) catch return null;
            p.document = p.document[semi + 2 ..];
            p.mode = .chars;
            return Event{ .character_data = p.char_buffer[0..n] };
        }

        return null;
    }

    fn isNameChar(c: u8) bool {
        return switch (c) {
            ':', 'A'...'Z', '_', 'a'...'z', '-', '.', '0'...'9' => true,
            else => false,
        };
    }

    fn skipWhitespace(p: *Parser) void {
        while (true) {
            switch (p.peek(0) orelse return) {
                ' ', '\t', '\n', '\r' => {
                    p.document = p.document[1..];
                },
                else => {
                    return;
                },
            }
        }
    }

    fn peek(p: *Parser, n: usize) ?u8 {
        if (p.document.len <= n)
            return null;

        return p.document[n];
    }
};

pub const Event = union(enum) {
    open_tag: []const u8,
    close_tag: []const u8,
    attribute: Attribute,
    comment: []const u8,
    processing_instruction: []const u8,
    character_data: []const u8,
};

pub const Attribute = struct {
    name: []const u8,
    raw_value: []const u8,
    char_buffer: [4]u8 = undefined,

    pub fn dupeValue(attr: Attribute, allocator: mem.Allocator) error{OutOfMemory}![]u8 {
        var list = std.ArrayList(u8).init(allocator);
        errdefer list.deinit();
        var attr_copy = attr;
        while (attr_copy.next()) |fragment|
            try list.appendSlice(fragment);
        return list.toOwnedSlice();
    }

    pub fn valueStartsWith(attr: Attribute, prefix: []const u8) bool {
        var attr_copy = attr;
        var i: usize = 0;

        while (attr_copy.next()) |fragment| {
            if (mem.startsWith(u8, fragment, prefix[i..])) {
                i += fragment.len;
            } else {
                return false;
            }
        }

        return i > prefix.len;
    }

    pub fn valueEql(attr: Attribute, value: []const u8) bool {
        var attr_copy = attr;
        var i: usize = 0;

        while (attr_copy.next()) |fragment| {
            if (mem.startsWith(u8, value[i..], fragment)) {
                i += fragment.len;
            } else {
                return false;
            }
        }

        return i == value.len;
    }

    pub fn next(attr: *Attribute) ?[]const u8 {
        if (attr.raw_value.len == 0)
            return null;

        if (attr.raw_value[0] == '&') {
            if (Parser.parseEntity(attr.raw_value[1..], &attr.char_buffer)) |semi| {
                const codepoint = mem.bytesToValue(u32, &attr.char_buffer);
                const n = std.unicode.utf8Encode(@intCast(u21, codepoint), &attr.char_buffer) catch return null;
                attr.raw_value = attr.raw_value[semi + 2 ..];
                return attr.char_buffer[0..n];
            } else {
                return null;
            }
        }

        var i: usize = 0;
        while (true) : (i += 1) {
            if (attr.raw_value.len == i or attr.raw_value[i] == '&') {
                const ret = attr.raw_value[0..i];
                attr.raw_value = attr.raw_value[i..];
                return ret;
            }
        }
    }
};
