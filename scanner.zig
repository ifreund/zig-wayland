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
    enumeration: *Enum,

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
    const Type = union(enum) {
        int,
        uint,
        fixed,
        string,
        new_id: []const u8,
        object: []const u8,
        array,
        fd,
    };
    name: []const u8,
    kind: Type,
    allow_null: bool,
    enum_name: ?[]const u8,
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

    var ctx = Context{
        .protocol = undefined,
        .interface = undefined,
        .message = undefined,
        .enumeration = undefined,
    };
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
        std.debug.warn("error reading xml: {}", .{err});
        std.os.exit(1);
    };
}

fn handleStart(ctx: *Context, name: []const u8, raw_atts: [*:null]?[*:0]const u8) !void {
    var atts = struct {
        name: ?[]const u8 = null,
        interface: ?[]const u8 = null,
        version: ?u32 = null,
        since: ?u32 = null,
        @"type": ?[]const u8 = null,
        value: ?[]const u8 = null,
        summary: ?[]const u8 = null,
        allow_null: ?bool = null,
        @"enum": ?[]const u8 = null,
        bitfield: ?bool = null,
    }{};

    var i: usize = 0;
    while (raw_atts[i]) |att| : (i += 2) {
        inline for (@typeInfo(@TypeOf(atts)).Struct.fields) |field| {
            if (mem.eql(u8, field.name, mem.span(att))) {
                const val = mem.span(raw_atts[i + 1].?);
                if (field.field_type == ?u32) {
                    @field(atts, field.name) = try std.fmt.parseInt(u32, val, 10);
                } else if (field.field_type == ?bool) {
                    // TODO: error if != true and != false
                    if (mem.eql(u8, val, "true"))
                        @field(atts, field.name) = true
                    else if (mem.eql(u8, val, "false"))
                        @field(atts, field.name) = false;
                } else {
                    @field(atts, field.name) = val;
                }
            }
        }
    }

    if (mem.eql(u8, name, "protocol")) {
        ctx.protocol = Protocol{ .name = try mem.dupe(gpa, u8, atts.name.?) };
    } else if (mem.eql(u8, name, "interface")) {
        ctx.interface = try ctx.protocol.interfaces.addOne();
        ctx.interface.* = .{
            .name = try mem.dupe(gpa, u8, atts.name.?),
            .version = atts.version.?,
        };
    } else if (mem.eql(u8, name, "event") or mem.eql(u8, name, "request")) {
        const list = if (mem.eql(u8, name, "event")) &ctx.interface.events else &ctx.interface.requests;
        ctx.message = try list.addOne();
        ctx.message.* = .{
            .name = try mem.dupe(gpa, u8, atts.name.?),
            .destructor = if (atts.@"type") |t| mem.eql(u8, t, "destructor") else false,
            .since = atts.since orelse 1,
        };
    } else if (mem.eql(u8, name, "arg")) {
        const kind = std.meta.stringToEnum(@TagType(Arg.Type), mem.span(atts.@"type".?)) orelse
            return error.InvalidType;
        try ctx.message.args.append(.{
            .name = try mem.dupe(gpa, u8, atts.name.?),
            .kind = switch (kind) {
                .object => .{ .object = try mem.dupe(gpa, u8, atts.name.?) },
                .new_id => .{ .new_id = try mem.dupe(gpa, u8, atts.name.?) },
                .int => .int,
                .uint => .uint,
                .fixed => .fixed,
                .string => .string,
                .array => .array,
                .fd => .fd,
            },
            // TODO: enforce != false -> error, require if object/string/array
            .allow_null = if (atts.allow_null) |a_n| a_n else false,
            .enum_name = if (atts.@"enum") |e| try mem.dupe(gpa, u8, e) else null,
        });
    } else if (mem.eql(u8, name, "enum")) {
        try ctx.interface.enums.append(.{
            .name = try mem.dupe(gpa, u8, atts.name.?),
            .since = atts.since orelse 1,
            .bitfield = if (atts.bitfield) |b| b else false,
        });
    } else if (mem.eql(u8, name, "entry")) {
        try ctx.enumeration.entries.append(.{
            .name = try mem.dupe(gpa, u8, atts.name.?),
            .since = atts.since orelse 1,
            .value = try mem.dupe(gpa, u8, atts.value.?),
        });
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
