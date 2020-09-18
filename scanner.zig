const std = @import("std");

const mem = std.mem;

const c = @cImport({
    @cInclude("expat.h");
});

const gpa = std.heap.c_allocator;

const Context = struct {
    const Self = @This();

    protocol: Protocol,
    interface: *Interface,
    message: *Message,

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
    requests: std.ArrayList(Message) = std.ArrayList(Message).init(gpa),
    events: std.ArrayList(Message) = std.ArrayList(Message).init(gpa),
    enums: std.ArrayList(Enum) = std.ArrayList(Enum).init(gpa),
};

const Message = struct {
    name: []const u8,
    since: u32,
    args: std.ArrayList(Arg) = std.ArrayList(Arg).init(gpa),
    destructor: bool,
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
    handleStart(ctx, mem.span(name.?), atts.?) catch |err| {
        std.debug.print("error reading xml: {}", .{err});
        std.os.exit(1);
    };
}

fn handleStart(ctx: *Context, name: []const u8, raw_atts: [*:null]?[*:0]const u8) !void {
    const atts = struct {
        name: ?[]const u8 = null,
        interface: ?[]const u8 = null,
        version: ?u32 = null,
        since: ?u32 = null,
        @"type": ?[]const u8 = null,
        value: ?[]const u8 = null,
        summary: ?[]const u8 = null,
        @"allow-null": ?[]const u8 = null,
        @"enum": ?[]const u8 = null,
        bitfield: ?[]const u8 = null,
    }{};

    var i: usize = 0;
    while (raw_atts[i]) |att| : (i += 2) {
        inline for (@typeInfo(@Type(atts)).Struct.fields) |field| {
            if (mem.eql(u8, field.name, mem.span(att))) {
                const val = mem.span(raw_atts[i + 1]);
                if (field.field_type == ?u32) {
                    @field(atts, field.name) = try std.fmt.parseInt(u32, val, 10);
                } else {
                    @field(atts, field.name) = val;
                }
            }
        }
    }

    if (mem.eql(name, "protocol")) {
        ctx.protocol = Protocol{ .name = try mem.dupe(atts.name.?) };
    } else if (mem.eql(name, "interface")) {
        ctx.interface = try ctx.protocol.interfaces.addOne();
        ctx.interface.* = .{
            .name = try mem.dupe(atts.name.?),
            .version = atts.version.?,
        };
    } else if (mem.eql(name, "event") or mem.eql(name, "request")) {
        const list = if (mem.eql(name, "event")) &ctx.interface.events else &ctx.interface.requests;
        ctx.message = try list.addOne();
        ctx.message.* = .{
            .name = try mem.dupe(atts.name.?),
            .destructor = if (atts.@"type") |t| mem.eql(u8, t, "destructor") else false,
            .since = atts.since orelse 1,
        };
    } else if (mem.eql(name, "arg")) {
        // TODO
    } else if (mem.eql(name, "enum")) {
        // TODO
    } else if (mem.eql(name, "entry")) {
        // TODO
    }
}

fn end(user_data: ?*c_void, name: ?[*:0]const u8) callconv(.C) void {
    const ctx = @intToPtr(*Context, @ptrToInt(user_data));
    defer ctx.character_data.items.len = 0;
}

fn characterData(user_data: ?*c_void, s: ?[*]const u8, len: i32) callconv(.C) void {
    const ctx = @intToPtr(*Context, @ptrToInt(user_data));
    ctx.character_data.appendSlice(s.?[0..@intCast(usize, len)]) catch std.os.exit(1);
}
