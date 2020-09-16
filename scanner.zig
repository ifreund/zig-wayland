const std = @import("std");

const c = @cImport({
    @cInclude("expat.h");
});

const gpa = std.heap.c_allocator;

const Context = struct {
    const Self = @This();

    character_data: std.ArrayList(u8) = std.ArrayList(u8).init(gpa),

    fn deinit(self: Self) void {
        self.character_data.deinit();
    }
};

const Protocol = struct {
    name: []const u8,
    interfaces: std.ArrayList(Interface) = std.ArrayList(Interface).init(gpa),
};

const Interface = struct {
    name: []const u8,
    version: u32,
    since: u32,
    requests: std.ArrayList(Message) = std.ArrayList(Message).init(gpa),
    events: std.ArrayList(Message) = std.ArrayList(Message).init(gpa),
    enums: std.ArrayList(Enum) = std.ArrayList(Enum).init(gpa),
};

const Message = struct {
    name: []const u8,
    since: u32,
    args: std.ArrayList(Arg) = std.ArrayList(Arg).init(gpa),
};

const Arg = struct {
    name: []const u8,
    kind: enum {
        new_id,
        int,
        uint,
        fixed,
        string,
        object,
        array,
        fd,
    },
};

const Enum = struct {
    name: []const u8,
    since: u32,
    entries: std.ArrayList(Entry) = std.ArrayList(Entry).init(gpa),
    bitfield: bool,
};

const Entry = struct {
    name: []const u8,
    since: u32,
    value: []const u8,
};

pub fn main() !void {
    const filename = std.os.argv[1];
    const file = try std.fs.cwd().openFileZ(filename, .{});
    defer file.close();

    const parser = c.XML_ParserCreate(null) orelse return error.ParserCreateFailed;
    defer c.XML_ParserFree(parser);

    var ctx = Context{};
    defer ctx.deinit();

    c.XML_SetUserData(parser, &ctx);
    c.XML_SetElementHandler(parser, start, end);
    c.XML_SetCharacterDataHandler(parser, characterData);

    while (true) {
        var buf: [4096]u8 = undefined;
        const read = try file.readAll(&buf);
        const is_final = read < buf.len;
        if (c.XML_Parse(parser, &buf, @intCast(i32, read), if (is_final) 1 else 0) == .XML_STATUS_ERROR)
            return error.ParserError;
        if (is_final) break;
    }
}

fn start(user_data: ?*c_void, name: ?[*:0]const u8, atts: ?[*:null]?[*:0]const u8) callconv(.C) void {
    const ctx = @intToPtr(*Context, @ptrToInt(user_data));
}

fn end(user_data: ?*c_void, name: ?[*:0]const u8) callconv(.C) void {
    const ctx = @intToPtr(*Context, @ptrToInt(user_data));
    defer ctx.character_data.items.len = 0;
}

fn characterData(user_data: ?*c_void, s: ?[*]const u8, len: i32) callconv(.C) void {
    const ctx = @intToPtr(*Context, @ptrToInt(user_data));
    ctx.character_data.appendSlice(s.?[0..@intCast(usize, len)]) catch std.os.exit(1);
}
