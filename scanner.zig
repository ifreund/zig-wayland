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

    fn emitClient(protocol: Protocol, writer: anytype) !void {
        try writer.writeAll(
            \\const wayland = @import("wayland.zig");
            \\const client = wayland.client;
            \\const common = wayland.common;
        );
        for (protocol.interfaces.items) |interface|
            try interface.emitClient(writer);
    }

    fn emitInterface(protocol: Protocol, writer: anytype) !void {
        try writer.writeAll(
            \\const wayland = @import("wayland.zig");
            \\const common = wayland.common;
        );
        for (protocol.interfaces.items) |interface|
            try interface.emitInterface(writer);
    }
};

const Interface = struct {
    name: []const u8,
    version: u32,
    requests: std.ArrayList(Message) = std.ArrayList(Message).init(gpa),
    events: std.ArrayList(Message) = std.ArrayList(Message).init(gpa),
    enums: std.ArrayList(Enum) = std.ArrayList(Enum).init(gpa),

    fn emitClient(interface: Interface, writer: anytype) !void {
        var buf: [1024]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buf);
        try printIdentifier(fbs.writer(), case(.title, trimPrefix(interface.name)));
        const title_case = fbs.getWritten();
        try printIdentifier(fbs.writer(), trimPrefix(interface.name));
        const snake_case = fbs.getWritten()[title_case.len..];

        try writer.print(
            \\pub const {} = opaque {{
            \\ pub const interface = &wayland.common.{}.{};
        , .{ title_case, prefix(interface.name), snake_case });

        for (interface.enums.items) |e| try e.emit(writer);

        // Client only for now TODO: generate server code
        if (interface.events.items.len > 0) {
            try writer.writeAll(
                \\ pub const Event = union (enum) {
            );
            for (interface.events.items) |event| try event.emitEventField(writer);
            try writer.writeAll(
                \\ };
                \\
            );
            try writer.print(
                \\ pub fn setListener(
                \\     {}: *{},
                \\     comptime T: type,
                \\     listener: fn ({}: *{}, event: Event, data: T) void,
                \\     data: T,
                \\ ) !void {{
                \\     const proxy = @ptrCast(*client.Proxy, {});
                \\     try proxy.addDispatcher(common.Dispatcher({}, T).dispatcher, listener, data);
                \\ }}
                \\
            , .{ snake_case, title_case, snake_case, title_case, snake_case, title_case });
        }

        for (interface.requests.items) |request, opcode|
            try request.emitRequestFn(writer, interface, opcode);

        if (mem.eql(u8, interface.name, "wl_display"))
            try writer.writeAll(@embedFile("src/client_display_functions.zig"));

        try writer.writeAll("};\n");
    }

    fn emitInterface(interface: Interface, writer: anytype) !void {
        try writer.writeAll("pub const ");
        try printIdentifier(writer, trimPrefix(interface.name));
        try writer.print(
            \\ = common.Interface{{
            \\ .name = "{}",
            \\ .version = {},
            \\ .method_count = {},
        , .{
            interface.name,
            interface.version,
            interface.requests.items.len,
        });
        if (interface.requests.items.len > 0) {
            try writer.writeAll(".methods = &[_]common.Message{");
            for (interface.requests.items) |request| try request.emitMessage(writer);
            try writer.writeAll("},");
        } else {
            try writer.writeAll(".methods = null,");
        }
        try writer.print(".event_count = {},", .{interface.events.items.len});
        if (interface.events.items.len > 0) {
            try writer.writeAll(".events = &[_]common.Message{");
            for (interface.events.items) |event| try event.emitMessage(writer);
            try writer.writeAll("},");
        } else {
            try writer.writeAll(".events = null,");
        }
        try writer.writeAll("};");
    }
};

const Message = struct {
    name: []const u8,
    since: u32,
    args: std.ArrayList(Arg) = std.ArrayList(Arg).init(gpa),
    kind: union(enum) {
        normal: void,
        constructor: ?[]const u8,
        destructor: void,
    },

    fn emitMessage(message: Message, writer: anytype) !void {
        try writer.print(".{{ .name = \"{}\", .signature = \"", .{message.name});
        for (message.args.items) |arg| try arg.emitSignature(writer);
        try writer.writeAll("\", .types = &[_]?*const common.Interface{");
        for (message.args.items) |arg| {
            switch (arg.kind) {
                .object, .new_id => |interface| if (interface) |i|
                    try writer.print("&common.{}.{},", .{ prefix(i), trimPrefix(i) })
                else
                    try writer.writeAll("null,"),
                else => try writer.writeAll("null,"),
            }
        }
        try writer.writeAll("}, },");
    }

    fn emitEventField(message: Message, writer: anytype) !void {
        try printIdentifier(writer, message.name);
        try writer.writeAll(": struct {");
        for (message.args.items) |arg| {
            if (arg.kind == .new_id and arg.kind.new_id == null) {
                // TODO
            } else {
                try printIdentifier(writer, arg.name);
                try writer.writeByte(':');
                // See notes on NULL in doc comment for wl_argument in wayland-util.h
                if (arg.kind == .object and !arg.allow_null) try writer.writeByte('?');
                try arg.emitType(writer);
                try writer.writeByte(',');
            }
        }
        try writer.writeAll("},\n");
    }

    fn emitRequestFn(message: Message, writer: anytype, interface: Interface, opcode: usize) !void {
        try writer.writeAll("pub fn ");
        try printIdentifier(writer, case(.camel, message.name));
        try writer.writeByte('(');
        try printIdentifier(writer, trimPrefix(interface.name));
        try writer.writeAll(": *");
        try printIdentifier(writer, case(.title, trimPrefix(interface.name)));
        for (message.args.items) |arg| {
            if (arg.kind == .new_id) {
                if (arg.kind.new_id == null) try writer.writeAll(", comptime T: type, version: u32");
            } else {
                try writer.writeByte(',');
                try printIdentifier(writer, arg.name);
                try writer.writeByte(':');
                try arg.emitType(writer);
            }
        }
        switch (message.kind) {
            .normal, .destructor => try writer.writeAll(") void {"),
            .constructor => |new_iface| if (new_iface) |i| {
                try writer.writeAll(") !*");
                try printIdentifier(writer, case(.title, trimPrefix(i)));
                try writer.writeAll("{");
            } else {
                try writer.writeAll(") !*T {");
            },
        }
        try writer.writeAll("const proxy = @ptrCast(*client.Proxy,");
        try printIdentifier(writer, trimPrefix(interface.name));
        try writer.writeAll(");");
        if (message.kind != .destructor) {
            try writer.writeAll("var args = [_]common.Argument{");
            for (message.args.items) |arg| {
                switch (arg.kind) {
                    .int, .uint, .fixed, .string, .object, .array, .fd => {
                        try writer.writeAll(".{ .");
                        try arg.emitSignature(writer);
                        try writer.writeAll(" = ");
                        try printIdentifier(writer, arg.name);
                        try writer.writeAll("},");
                    },
                    .new_id => |new_iface| {
                        if (new_iface == null) {
                            try writer.writeAll(
                                \\.{ . s = T.interface.name },
                                \\.{ . u = version },
                            );
                        }
                        try writer.writeAll(".{ . o = null },");
                    },
                }
            }
            try writer.writeAll("};\n");
        }
        switch (message.kind) {
            .normal => try writer.print("proxy.marshal({}, &args);", .{opcode}),
            .constructor => |new_iface| {
                if (new_iface) |i| {
                    try writer.writeAll("return @ptrCast(*");
                    try printIdentifier(writer, case(.title, trimPrefix(i)));
                    try writer.print(", try proxy.marshalConstructor({}, &args, ", .{opcode});
                    try printIdentifier(writer, case(.title, trimPrefix(i)));
                    try writer.writeAll(".interface));");
                } else {
                    try writer.print("return @ptrCast(*T, proxy.marshalConstructorVersioned({}, &args, T.interface, version));", .{opcode});
                }
            },
            .destructor => try writer.writeAll("proxy.destroy();"),
        }
        try writer.writeAll("}\n");
    }
};

const Arg = struct {
    const Type = union(enum) {
        int,
        uint,
        fixed,
        string,
        new_id: ?[]const u8,
        object: ?[]const u8,
        array,
        fd,
    };
    name: []const u8,
    kind: Type,
    allow_null: bool,
    enum_name: ?[]const u8,

    fn emitSignature(arg: Arg, writer: anytype) !void {
        switch (arg.kind) {
            .int => try writer.writeByte('i'),
            .uint => try writer.writeByte('u'),
            .fixed => try writer.writeByte('f'),
            .string => try writer.writeByte('s'),
            .new_id => |interface| if (interface == null)
                try writer.writeAll("sun")
            else
                try writer.writeByte('n'),
            .object => try writer.writeByte('o'),
            .array => try writer.writeByte('a'),
            .fd => try writer.writeByte('h'),
        }
    }

    /// if of type new_id, must have non-null interface
    fn emitType(arg: Arg, writer: anytype) !void {
        switch (arg.kind) {
            .int => try writer.writeAll("i32"),
            .uint => try writer.writeAll("u32"),
            .fixed => try writer.writeAll("common.Fixed"),
            .string => {
                if (arg.allow_null) try writer.writeByte('?');
                try writer.writeAll("[*:0]const u8");
            },
            .new_id, .object => |interface| if (interface) |i| {
                if (arg.allow_null) try writer.writeAll("?*") else try writer.writeByte('*');
                try printIdentifier(writer, case(.title, trimPrefix(interface.?)));
            } else {
                std.debug.assert(arg.kind == .object);
                if (arg.allow_null) try writer.writeByte('?');
                try writer.writeAll("*common.Object");
            },
            .array => {
                if (arg.allow_null) try writer.writeByte('?');
                try writer.writeAll("*common.Array");
            },
            .fd => try writer.writeAll("std.os.fd_t"),
        }
    }
};

const Enum = struct {
    name: []const u8,
    since: u32,
    entries: std.ArrayList(Entry) = std.ArrayList(Entry).init(gpa),
    bitfield: bool,

    fn emit(e: Enum, writer: anytype) !void {
        try writer.writeAll("pub const ");
        try printIdentifier(writer, case(.title, e.name));
        try writer.writeAll(" = enum {");
        for (e.entries.items) |entry| {
            try printIdentifier(writer, entry.name);
            try writer.print("= {},", .{entry.value});
        }
        try writer.writeAll("};\n");
    }
};

const Entry = struct {
    name: []const u8,
    since: u32,
    value: []const u8,
};

const Scanner = struct {
    /// Map from namespace to list of generated files
    const Map = std.hash_map.StringHashMap(std.ArrayListUnmanaged([]const u8));
    client: Map = Map.init(gpa),
    common: Map = Map.init(gpa),

    fn scanProtocol(scanner: *Scanner, xml_filename: []const u8) !void {
        const xml_file = try std.fs.cwd().openFile(xml_filename, .{});
        defer xml_file.close();

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
            const read = try xml_file.readAll(&buf);
            const is_final = read < buf.len;
            if (c.XML_Parse(parser, &buf, @intCast(i32, read), if (is_final) 1 else 0) == .XML_STATUS_ERROR)
                return error.ParserError;
            if (is_final) break;
        }

        const xml_basename = std.fs.path.basename(xml_filename);
        const protcol_name = xml_basename[0 .. xml_basename.len - 4];
        const namespace = if (mem.eql(u8, protcol_name, "wayland")) "wl" else prefix(protcol_name);

        const client_filename = try mem.concat(gpa, u8, &[_][]const u8{ protcol_name, "_client.zig" });
        const client_file = try std.fs.cwd().createFile(client_filename, .{});
        defer client_file.close();
        try ctx.protocol.emitClient(client_file.writer());
        try (try scanner.client.getOrPutValue(namespace, .{})).value.append(gpa, try mem.dupe(gpa, u8, client_filename));

        const common_filename = try mem.concat(gpa, u8, &[_][]const u8{ protcol_name, "_common.zig" });
        const common_file = try std.fs.cwd().createFile(common_filename, .{});
        defer common_file.close();
        try ctx.protocol.emitInterface(common_file.writer());
        try (try scanner.common.getOrPutValue(namespace, .{})).value.append(gpa, try mem.dupe(gpa, u8, common_filename));
    }
};

pub fn main() !void {
    var scanner = Scanner{};
    const argv = std.os.argv;
    for (argv[1..]) |xml_filename| {
        try scanner.scanProtocol(mem.span(xml_filename));
    }

    {
        const client_file = try std.fs.cwd().createFile("client.zig", .{});
        defer client_file.close();
        const writer = client_file.writer();
        try writer.writeAll(@embedFile("src/client_core.zig"));

        var iter = scanner.client.iterator();
        while (iter.next()) |entry| {
            try writer.print("pub const {} = struct {{", .{entry.key});
            for (entry.value.items) |generated_file| {
                try writer.print("pub usingnamespace @import(\"{}\");", .{generated_file});
            }
            try writer.writeAll("};\n");
        }
    }

    {
        const common_file = try std.fs.cwd().createFile("common.zig", .{});
        defer common_file.close();
        const writer = common_file.writer();
        try writer.writeAll(@embedFile("src/common_core.zig"));

        var iter = scanner.common.iterator();
        while (iter.next()) |entry| {
            try writer.print("pub const {} = struct {{", .{entry.key});
            for (entry.value.items) |generated_file| {
                try writer.print("pub usingnamespace @import(\"{}\");", .{generated_file});
            }
            try writer.writeAll("};\n");
        }
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
            .kind = if (atts.@"type" != null and mem.eql(u8, atts.@"type".?, "destructor")) .destructor else .normal,
            .since = atts.since orelse 1,
        };
    } else if (mem.eql(u8, name, "arg")) {
        const kind = std.meta.stringToEnum(@TagType(Arg.Type), mem.span(atts.@"type".?)) orelse
            return error.InvalidType;
        if (kind == .new_id) ctx.message.kind = .{ .constructor = if (atts.interface) |f| try mem.dupe(gpa, u8, f) else null };
        try ctx.message.args.append(.{
            .name = try mem.dupe(gpa, u8, atts.name.?),
            .kind = switch (kind) {
                .object => .{ .object = if (atts.interface) |f| try mem.dupe(gpa, u8, f) else null },
                .new_id => .{ .new_id = if (atts.interface) |f| try mem.dupe(gpa, u8, f) else null },
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
        ctx.enumeration = try ctx.interface.enums.addOne();
        ctx.enumeration.* = .{
            .name = try mem.dupe(gpa, u8, atts.name.?),
            .since = atts.since orelse 1,
            .bitfield = if (atts.bitfield) |b| b else false,
        };
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

fn prefix(s: []const u8) []const u8 {
    return s[0..mem.indexOfScalar(u8, s, '_').?];
}

fn trimPrefix(s: []const u8) []const u8 {
    return s[mem.indexOfScalar(u8, s, '_').? + 1 ..];
}

var case_buf: [512]u8 = undefined;
fn case(out_case: enum { title, camel }, snake_case: []const u8) []const u8 {
    var i: usize = 0;
    var upper = out_case == .title;
    for (snake_case) |ch| {
        if (ch == '_') {
            upper = true;
            continue;
        }
        case_buf[i] = if (upper) std.ascii.toUpper(ch) else ch;
        i += 1;
        upper = false;
    }
    return case_buf[0..i];
}

fn printIdentifier(writer: anytype, identifier: []const u8) !void {
    if (isValidIdentifier(identifier))
        try writer.writeAll(identifier)
    else
        try writer.print("@\"{}\"", .{identifier});
}

fn isValidIdentifier(identifier: []const u8) bool {
    // !keyword [A-Za-z_] [A-Za-z0-9_]*
    if (identifier.len == 0) return false;
    for (identifier) |ch, i| switch (ch) {
        'A'...'Z', 'a'...'z', '_' => {},
        '0'...'9' => if (i == 0) return false,
        else => return false,
    };
    return std.zig.Token.getKeyword(identifier) == null;
}

test "parsing" {
    const testing = std.testing;

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

    const sample = @embedFile("protocol/wayland.xml");
    if (c.XML_Parse(parser, sample, sample.len, 1) == .XML_STATUS_ERROR)
        return error.ParserError;

    testing.expectEqualSlices(u8, "wayland", ctx.protocol.name);
    testing.expectEqual(@as(usize, 22), ctx.protocol.interfaces.items.len);

    {
        const wl_display = ctx.protocol.interfaces.items[0];
        testing.expectEqualSlices(u8, "wl_display", wl_display.name);
        testing.expectEqual(@as(u32, 1), wl_display.version);
        testing.expectEqual(@as(usize, 2), wl_display.requests.items.len);
        testing.expectEqual(@as(usize, 2), wl_display.events.items.len);
        testing.expectEqual(@as(usize, 1), wl_display.enums.items.len);

        {
            const sync = wl_display.requests.items[0];
            testing.expectEqualSlices(u8, "sync", sync.name);
            testing.expectEqual(@as(u32, 1), sync.since);
            testing.expectEqual(@as(usize, 1), sync.args.items.len);
            {
                const callback = sync.args.items[0];
                testing.expectEqualSlices(u8, "callback", callback.name);
                testing.expect(callback.kind == .new_id);
                testing.expectEqualSlices(u8, "wl_callback", callback.kind.new_id.?);
                testing.expectEqual(false, callback.allow_null);
                testing.expectEqual(@as(?[]const u8, null), callback.enum_name);
            }
            testing.expectEqual(false, sync.destructor);
        }

        {
            const error_event = wl_display.events.items[0];
            testing.expectEqualSlices(u8, "error", error_event.name);
            testing.expectEqual(@as(u32, 1), error_event.since);
            testing.expectEqual(@as(usize, 3), error_event.args.items.len);
            {
                const object_id = error_event.args.items[0];
                testing.expectEqualSlices(u8, "object_id", object_id.name);
                testing.expectEqual(Arg.Type{ .object = null }, object_id.kind);
                testing.expectEqual(false, object_id.allow_null);
                testing.expectEqual(@as(?[]const u8, null), object_id.enum_name);
            }
            {
                const code = error_event.args.items[1];
                testing.expectEqualSlices(u8, "code", code.name);
                testing.expectEqual(Arg.Type.uint, code.kind);
                testing.expectEqual(false, code.allow_null);
                testing.expectEqual(@as(?[]const u8, null), code.enum_name);
            }
            {
                const message = error_event.args.items[2];
                testing.expectEqualSlices(u8, "message", message.name);
                testing.expectEqual(Arg.Type.string, message.kind);
                testing.expectEqual(false, message.allow_null);
                testing.expectEqual(@as(?[]const u8, null), message.enum_name);
            }
        }

        {
            const error_enum = wl_display.enums.items[0];
            testing.expectEqualSlices(u8, "error", error_enum.name);
            testing.expectEqual(@as(u32, 1), error_enum.since);
            testing.expectEqual(@as(usize, 4), error_enum.entries.items.len);
            {
                const invalid_object = error_enum.entries.items[0];
                testing.expectEqualSlices(u8, "invalid_object", invalid_object.name);
                testing.expectEqual(@as(u32, 1), invalid_object.since);
                testing.expectEqualSlices(u8, "0", invalid_object.value);
            }
            {
                const invalid_method = error_enum.entries.items[1];
                testing.expectEqualSlices(u8, "invalid_method", invalid_method.name);
                testing.expectEqual(@as(u32, 1), invalid_method.since);
                testing.expectEqualSlices(u8, "1", invalid_method.value);
            }
            {
                const no_memory = error_enum.entries.items[2];
                testing.expectEqualSlices(u8, "no_memory", no_memory.name);
                testing.expectEqual(@as(u32, 1), no_memory.since);
                testing.expectEqualSlices(u8, "2", no_memory.value);
            }
            {
                const implementation = error_enum.entries.items[3];
                testing.expectEqualSlices(u8, "implementation", implementation.name);
                testing.expectEqual(@as(u32, 1), implementation.since);
                testing.expectEqualSlices(u8, "3", implementation.value);
            }
            testing.expectEqual(false, error_enum.bitfield);
        }
    }
}
