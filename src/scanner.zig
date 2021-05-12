const std = @import("std");
const fs = std.fs;
const mem = std.mem;

const xml = @import("xml.zig");

const gpa = &allocator_instance.allocator;
var allocator_instance = std.heap.GeneralPurposeAllocator(.{}){};

pub fn scan(root_dir: fs.Dir, out_path: []const u8, wayland_xml: []const u8, protocols: []const []const u8) !void {
    var out_dir = try root_dir.makeOpenPath(out_path, .{});
    defer out_dir.close();

    const wayland_file = try out_dir.createFile("wayland.zig", .{});
    try wayland_file.writeAll(@embedFile("wayland.zig"));
    defer wayland_file.close();

    var scanner = Scanner{};

    try scanner.scanProtocol(root_dir, out_dir, wayland_xml);
    for (protocols) |xml_path|
        try scanner.scanProtocol(root_dir, out_dir, xml_path);

    {
        const client_core_file = try out_dir.createFile("wayland_client_core.zig", .{});
        defer client_core_file.close();
        try client_core_file.writeAll(@embedFile("wayland_client_core.zig"));

        const client_file = try out_dir.createFile("client.zig", .{});
        defer client_file.close();
        const writer = client_file.writer();

        var iter = scanner.client.iterator();
        while (iter.next()) |entry| {
            try writer.print("pub const {s} = struct {{", .{entry.key});
            if (mem.eql(u8, entry.key, "wl"))
                try writer.writeAll("pub usingnamespace @import(\"wayland_client_core.zig\");\n");
            for (entry.value.items) |generated_file|
                try writer.print("pub usingnamespace @import(\"{s}\");", .{generated_file});
            try writer.writeAll("};\n");
        }
    }

    {
        const server_core_file = try out_dir.createFile("wayland_server_core.zig", .{});
        defer server_core_file.close();
        try server_core_file.writeAll(@embedFile("wayland_server_core.zig"));

        const server_file = try out_dir.createFile("server.zig", .{});
        defer server_file.close();
        const writer = server_file.writer();

        var iter = scanner.server.iterator();
        while (iter.next()) |entry| {
            try writer.print("pub const {s} = struct {{", .{entry.key});
            if (mem.eql(u8, entry.key, "wl"))
                try writer.writeAll("pub usingnamespace @import(\"wayland_server_core.zig\");\n");
            for (entry.value.items) |generated_file|
                try writer.print("pub usingnamespace @import(\"{s}\");", .{generated_file});
            try writer.writeAll("};\n");
        }
    }

    {
        const common_file = try out_dir.createFile("common.zig", .{});
        defer common_file.close();
        const writer = common_file.writer();
        try writer.writeAll(@embedFile("common_core.zig"));

        var iter = scanner.common.iterator();
        while (iter.next()) |entry| {
            try writer.print("pub const {s} = struct {{", .{entry.key});
            for (entry.value.items) |generated_file|
                try writer.print("pub usingnamespace @import(\"{s}\");", .{generated_file});
            try writer.writeAll("};\n");
        }
    }
}

const Side = enum {
    client,
    server,
};

const Scanner = struct {
    /// Map from namespace to list of generated files
    const Map = std.hash_map.StringHashMap(std.ArrayListUnmanaged([]const u8));
    client: Map = Map.init(gpa),
    server: Map = Map.init(gpa),
    common: Map = Map.init(gpa),

    fn scanProtocol(scanner: *Scanner, root_dir: fs.Dir, out_dir: fs.Dir, xml_path: []const u8) !void {
        const xml_file = try root_dir.openFile(xml_path, .{});
        defer xml_file.close();

        var arena = std.heap.ArenaAllocator.init(gpa);
        defer arena.deinit();

        const xml_bytes = try xml_file.readToEndAlloc(&arena.allocator, 512 * 4096);
        const protocol = try Protocol.parseXML(&arena.allocator, xml_bytes);

        const protocol_name = try gpa.dupe(u8, protocol.name);
        const protocol_namespace = try gpa.dupe(u8, protocol.namespace);

        {
            const client_filename = try mem.concat(gpa, u8, &[_][]const u8{ protocol_name, "_client.zig" });
            const client_file = try out_dir.createFile(client_filename, .{});
            defer client_file.close();
            try protocol.emitClient(client_file.writer());
            try (try scanner.client.getOrPutValue(protocol_namespace, .{})).value.append(gpa, client_filename);
        }

        {
            const server_filename = try mem.concat(gpa, u8, &[_][]const u8{ protocol_name, "_server.zig" });
            const server_file = try out_dir.createFile(server_filename, .{});
            defer server_file.close();
            try protocol.emitServer(server_file.writer());
            try (try scanner.server.getOrPutValue(protocol_namespace, .{})).value.append(gpa, server_filename);
        }

        {
            const common_filename = try mem.concat(gpa, u8, &[_][]const u8{ protocol_name, "_common.zig" });
            const common_file = try out_dir.createFile(common_filename, .{});
            defer common_file.close();
            try protocol.emitCommon(common_file.writer());
            try (try scanner.common.getOrPutValue(protocol_namespace, .{})).value.append(gpa, common_filename);
        }
    }
};

const Protocol = struct {
    name: []const u8,
    namespace: []const u8,
    copyright: ?[]const u8,
    toplevel_description: ?[]const u8,
    interfaces: std.ArrayList(Interface),

    fn parseXML(allocator: *mem.Allocator, xml_bytes: []const u8) !Protocol {
        var parser = xml.Parser.init(xml_bytes);
        while (parser.next()) |ev| switch (ev) {
            .open_tag => |tag| if (mem.eql(u8, tag, "protocol")) return parse(allocator, &parser),
            else => {},
        };
        return error.UnexpectedEndOfFile;
    }

    fn parse(allocator: *mem.Allocator, parser: *xml.Parser) !Protocol {
        var name: ?[]const u8 = null;
        var copyright: ?[]const u8 = null;
        var toplevel_description: ?[]const u8 = null;
        var interfaces = std.ArrayList(Interface).init(allocator);
        while (parser.next()) |ev| switch (ev) {
            .open_tag => |tag| {
                if (mem.eql(u8, tag, "copyright")) {
                    if (copyright != null)
                        return error.DuplicateCopyright;
                    const e = parser.next() orelse return error.UnexpectedEndOfFile;
                    switch (e) {
                        .character_data => |data| copyright = try allocator.dupe(u8, data),
                        else => return error.BadCopyright,
                    }
                } else if (mem.eql(u8, tag, "description")) {
                    if (toplevel_description != null)
                        return error.DuplicateToplevelDescription;
                    while (parser.next()) |e| {
                        switch (e) {
                            .character_data => |data| {
                                toplevel_description = try allocator.dupe(u8, data);
                                break;
                            },
                            .attribute => continue,
                            else => return error.BadToplevelDescription,
                        }
                    } else {
                        return error.UnexpectedEndOfFile;
                    }
                } else if (mem.eql(u8, tag, "interface")) {
                    try interfaces.append(try Interface.parse(allocator, parser));
                }
            },
            .attribute => |attr| if (mem.eql(u8, attr.name, "name")) {
                if (name != null) return error.DuplicateName;
                name = try attr.dupeValue(allocator);
            },
            .close_tag => |tag| if (mem.eql(u8, tag, "protocol")) {
                if (interfaces.items.len == 0) return error.NoInterfaces;
                return Protocol{
                    .name = name orelse return error.MissingName,
                    // TODO: support mixing namespaces in a protocol
                    .namespace = prefix(interfaces.items[0].name) orelse return error.NoNamespace,
                    .interfaces = interfaces,

                    // Missing copyright or toplevel description is bad style, but not illegal.
                    .copyright = copyright,
                    .toplevel_description = toplevel_description,
                };
            },
            else => {},
        };
        return error.UnexpectedEndOfFile;
    }

    fn emitCopyrightAndToplevelDescription(protocol: Protocol, writer: anytype) !void {
        try writer.writeAll("// Generated by zig-wayland\n\n");
        if (protocol.copyright) |copyright| {
            var it = mem.split(copyright, "\n");
            while (it.next()) |line| {
                try writer.print("// {s}\n", .{mem.trim(u8, line, &std.ascii.spaces)});
            }
            try writer.writeByte('\n');
        }
        if (protocol.toplevel_description) |toplevel_description| {
            var it = mem.split(toplevel_description, "\n");
            while (it.next()) |line| {
                try writer.print("// {s}\n", .{mem.trim(u8, line, &std.ascii.spaces)});
            }
            try writer.writeByte('\n');
        }
    }

    fn emitClient(protocol: Protocol, writer: anytype) !void {
        try protocol.emitCopyrightAndToplevelDescription(writer);
        try writer.writeAll(
            \\const os = @import("std").os;
            \\const client = @import("wayland.zig").client;
            \\const common = @import("common.zig");
        );
        for (protocol.interfaces.items) |interface|
            try interface.emit(.client, protocol.namespace, writer);
    }

    fn emitServer(protocol: Protocol, writer: anytype) !void {
        try protocol.emitCopyrightAndToplevelDescription(writer);
        try writer.writeAll(
            \\const os = @import("std").os;
            \\const server = @import("wayland.zig").server;
            \\const common = @import("common.zig");
        );
        for (protocol.interfaces.items) |interface|
            try interface.emit(.server, protocol.namespace, writer);
    }

    fn emitCommon(protocol: Protocol, writer: anytype) !void {
        try protocol.emitCopyrightAndToplevelDescription(writer);
        try writer.writeAll(
            \\const common = @import("common.zig");
        );
        for (protocol.interfaces.items) |interface|
            try interface.emitCommon(writer);
    }
};

const Interface = struct {
    name: []const u8,
    version: u32,
    requests: std.ArrayList(Message),
    events: std.ArrayList(Message),
    enums: std.ArrayList(Enum),

    fn parse(allocator: *mem.Allocator, parser: *xml.Parser) !Interface {
        var name: ?[]const u8 = null;
        var version: ?u32 = null;
        var requests = std.ArrayList(Message).init(allocator);
        var events = std.ArrayList(Message).init(allocator);
        var enums = std.ArrayList(Enum).init(allocator);

        while (parser.next()) |ev| switch (ev) {
            .open_tag => |tag| {
                // TODO: parse description
                if (mem.eql(u8, tag, "request"))
                    try requests.append(try Message.parse(allocator, parser))
                else if (mem.eql(u8, tag, "event"))
                    try events.append(try Message.parse(allocator, parser))
                else if (mem.eql(u8, tag, "enum"))
                    try enums.append(try Enum.parse(allocator, parser));
            },
            .attribute => |attr| {
                if (mem.eql(u8, attr.name, "name")) {
                    if (name != null) return error.DuplicateName;
                    name = try attr.dupeValue(allocator);
                } else if (mem.eql(u8, attr.name, "version")) {
                    if (version != null) return error.DuplicateVersion;
                    version = try std.fmt.parseInt(u32, try attr.dupeValue(allocator), 10);
                }
            },
            .close_tag => |tag| if (mem.eql(u8, tag, "interface")) {
                return Interface{
                    .name = name orelse return error.MissingName,
                    .version = version orelse return error.MissingVersion,
                    .requests = requests,
                    .events = events,
                    .enums = enums,
                };
            },
            else => {},
        };
        return error.UnexpectedEndOfFile;
    }

    fn emit(interface: Interface, side: Side, namespace: []const u8, writer: anytype) !void {
        var buf: [1024]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buf);
        try printIdentifier(fbs.writer(), case(.title, trimPrefix(interface.name)));
        const title_case = fbs.getWritten();
        try printIdentifier(fbs.writer(), trimPrefix(interface.name));
        const snake_case = fbs.getWritten()[title_case.len..];

        try writer.print(
            \\pub const {s} = opaque {{
            \\ pub const getInterface = common.{s}.{s}.getInterface;
        , .{ title_case, namespace, snake_case });

        for (interface.enums.items) |e| {
            try writer.writeAll("pub const ");
            try printIdentifier(writer, case(.title, e.name));
            try writer.print(" = common.{s}.{s}.", .{ namespace, snake_case });
            try printIdentifier(writer, case(.title, e.name));
            try writer.writeAll(";\n");
        }

        if (side == .client) {
            if (interface.events.items.len > 0) {
                try writer.writeAll("pub const Event = union(enum) {");
                for (interface.events.items) |event| try event.emitField(.client, writer);
                try writer.writeAll("};\n");
                try writer.print(
                    \\pub fn setListener(
                    \\    _{s}: *{s},
                    \\    comptime T: type,
                    \\    _listener: fn ({s}: *{s}, event: Event, data: T) void,
                    \\    _data: T,
                    \\) callconv(.Inline) void {{
                    \\    const _proxy = @ptrCast(*client.wl.Proxy, _{s});
                    \\    const _mut_data = @intToPtr(?*c_void, @ptrToInt(_data));
                    \\    _proxy.addDispatcher(common.Dispatcher({s}, T).dispatcher, _listener, _mut_data);
                    \\}}
                , .{ snake_case, title_case, snake_case, title_case, snake_case, title_case });
            }

            for (interface.requests.items) |request, opcode|
                try request.emitFn(side, writer, interface, opcode);

            if (mem.eql(u8, interface.name, "wl_display"))
                try writer.writeAll(@embedFile("client_display_functions.zig"));
        } else {
            try writer.print(
                \\pub fn create(_client: *server.wl.Client, _version: u32, _id: u32) !*{s} {{
                \\    return @ptrCast(*{s}, try server.wl.Resource.create(_client, {s}, _version, _id));
                \\}}
            , .{ title_case, title_case, title_case });

            try writer.print(
                \\pub fn destroy(_{s}: *{s}) void {{
                \\    return @ptrCast(*server.wl.Resource, _{s}).destroy();
                \\}}
            , .{ snake_case, title_case, snake_case });

            try writer.print(
                \\pub fn fromLink(_link: *server.wl.list.Link) *{s} {{
                \\    return @ptrCast(*{s}, server.wl.Resource.fromLink(_link));
                \\}}
            , .{ title_case, title_case });

            for ([_][2][]const u8{
                .{ "getLink", "*server.wl.list.Link" },
                .{ "getClient", "*server.wl.Client" },
                .{ "getId", "u32" },
                .{ "getVersion", "u32" },
                .{ "postNoMemory", "void" },
            }) |func|
                try writer.print(
                    \\pub fn {s}(_{s}: *{s}) {s} {{
                    \\    return @ptrCast(*server.wl.Resource, _{s}).{s}();
                    \\}}
                , .{ func[0], snake_case, title_case, func[1], snake_case, func[0] });

            const has_error = for (interface.enums.items) |e| {
                if (mem.eql(u8, e.name, "error")) break true;
            } else false;
            if (has_error) {
                try writer.print(
                    \\pub fn postError({s}: *{s}, _err: Error, _message: [*:0]const u8) void {{
                    \\    return @ptrCast(*server.wl.Resource, {s}).postError(@intCast(u32, @enumToInt(_err)), _message);
                    \\}}
                , .{ snake_case, title_case, snake_case });
            }

            if (interface.requests.items.len > 0) {
                try writer.writeAll("pub const Request = union(enum) {");
                for (interface.requests.items) |request| try request.emitField(.server, writer);
                try writer.writeAll("};\n");
                @setEvalBranchQuota(2500);
                try writer.print(
                    \\pub fn setHandler(
                    \\    _{s}: *{s},
                    \\    comptime T: type,
                    \\    handle_request: fn ({s}: *{s}, request: Request, data: T) void,
                    \\    comptime handle_destroy: ?fn ({s}: *{s}, data: T) void,
                    \\    _data: T,
                    \\) callconv(.Inline) void {{
                    \\    const _resource = @ptrCast(*server.wl.Resource, _{s});
                    \\    _resource.setDispatcher(
                    \\        common.Dispatcher({s}, T).dispatcher,
                    \\        handle_request,
                    \\        @intToPtr(?*c_void, @ptrToInt(_data)),
                    \\        if (handle_destroy) |_handler| struct {{
                    \\            fn _wrapper(__resource: *server.wl.Resource) callconv(.C) void {{
                    \\                @call(.{{ .modifier = .always_inline }}, _handler, .{{
                    \\                    @ptrCast(*{s}, __resource),
                    \\                    @intToPtr(T, @ptrToInt(__resource.getUserData())),
                    \\                }});
                    \\            }}
                    \\        }}._wrapper else null,
                    \\    );
                    \\}}
                , .{ snake_case, title_case, snake_case, title_case, snake_case, title_case, snake_case, title_case, title_case });
            } else {
                try writer.print(
                    \\pub fn setHandler(
                    \\    _{s}: *{s},
                    \\    comptime T: type,
                    \\    comptime handle_destroy: ?fn ({s}: *{s}, data: T) void,
                    \\    _data: T,
                    \\) callconv(.Inline) void {{
                    \\    const _resource = @ptrCast(*server.wl.Resource, {s});
                    \\    _resource.setDispatcher(
                    \\        null,
                    \\        null,
                    \\        @intToPtr(?*c_void, @ptrToInt(_data)),
                    \\        if (handle_destroy) |_handler| struct {{
                    \\            fn _wrapper(__resource: *server.wl.Resource) callconv(.C) void {{
                    \\                @call(.{{ .modifier = .always_inline }}, _handler, .{{
                    \\                    @ptrCast(*{s}, __resource),
                    \\                    @intToPtr(T, @ptrToInt(__resource.getUserData())),
                    \\                }});
                    \\            }}
                    \\        }}._wrapper else null,
                    \\    );
                    \\}}
                , .{ snake_case, title_case, snake_case, title_case, snake_case, title_case });
            }

            for (interface.events.items) |event, opcode|
                try event.emitFn(side, writer, interface, opcode);
        }

        try writer.writeAll("};\n");
    }

    fn emitCommon(interface: Interface, writer: anytype) !void {
        try writer.writeAll("pub const ");
        try printIdentifier(writer, trimPrefix(interface.name));

        // TODO: stop linking libwayland generated interface structs when
        // https://github.com/ziglang/zig/issues/131 is implemented
        //
        //try writer.print(
        //    \\ = struct {{
        //    \\ pub const interface = common.Interface{{
        //    \\  .name = "{}",
        //    \\  .version = {},
        //    \\  .method_count = {},
        //, .{
        //    interface.name,
        //    interface.version,
        //    interface.requests.items.len,
        //});
        //if (interface.requests.items.len > 0) {
        //    try writer.writeAll(".methods = &[_]common.Message{");
        //    for (interface.requests.items) |request| try request.emitMessage(writer);
        //    try writer.writeAll("},");
        //} else {
        //    try writer.writeAll(".methods = null,");
        //}
        //try writer.print(".event_count = {},", .{interface.events.items.len});
        //if (interface.events.items.len > 0) {
        //    try writer.writeAll(".events = &[_]common.Message{");
        //    for (interface.events.items) |event| try event.emitMessage(writer);
        //    try writer.writeAll("},");
        //} else {
        //    try writer.writeAll(".events = null,");
        //}
        //try writer.writeAll("};");

        try writer.print(
            \\ = struct {{
            \\ extern const {s}_interface: common.Interface;
            \\ pub fn getInterface() callconv(.Inline) *const common.Interface {{
            \\  return &{s}_interface;
            \\ }}
        , .{ interface.name, interface.name });

        for (interface.enums.items) |e| try e.emit(writer);
        try writer.writeAll("};");
    }
};

const Message = struct {
    name: []const u8,
    since: u32,
    args: std.ArrayList(Arg) = std.ArrayList(Arg),
    kind: union(enum) {
        normal: void,
        constructor: ?[]const u8,
        destructor: void,
    },

    fn parse(allocator: *mem.Allocator, parser: *xml.Parser) !Message {
        var name: ?[]const u8 = null;
        var since: ?u32 = null;
        var args = std.ArrayList(Arg).init(allocator);
        var destructor = false;

        while (parser.next()) |ev| switch (ev) {
            .open_tag => |tag| {
                // TODO: parse description
                if (mem.eql(u8, tag, "arg"))
                    try args.append(try Arg.parse(allocator, parser));
            },
            .attribute => |attr| {
                if (mem.eql(u8, attr.name, "name")) {
                    if (name != null) return error.DuplicateName;
                    name = try attr.dupeValue(allocator);
                } else if (mem.eql(u8, attr.name, "since")) {
                    if (since != null) return error.DuplicateSince;
                    since = try std.fmt.parseInt(u32, try attr.dupeValue(allocator), 10);
                } else if (mem.eql(u8, attr.name, "type")) {
                    if (attr.valueEql("destructor")) {
                        destructor = true;
                    } else {
                        return error.InvalidType;
                    }
                }
            },
            .close_tag => |tag| if (mem.eql(u8, tag, "request") or mem.eql(u8, tag, "event")) {
                return Message{
                    .name = name orelse return error.MissingName,
                    .since = since orelse 1,
                    .args = args,
                    .kind = blk: {
                        if (destructor) break :blk .destructor;
                        for (args.items) |arg|
                            if (arg.kind == .new_id) break :blk .{ .constructor = arg.kind.new_id };
                        break :blk .normal;
                    },
                };
            },
            else => {},
        };
        return error.UnexpectedEndOfFile;
    }

    // TODO: restore this code when zig issue #131 is resoleved
    //fn emitMessage(message: Message, writer: anytype) !void {
    //    try writer.print(".{{ .name = \"{}\", .signature = \"", .{message.name});
    //    for (message.args.items) |arg| try arg.emitSignature(writer);
    //    try writer.writeAll("\", .types = ");
    //    if (message.args.items.len > 0) {
    //        try writer.writeAll("&[_]?*const common.Interface{");
    //        for (message.args.items) |arg| {
    //            switch (arg.kind) {
    //                .object, .new_id => |interface| if (interface) |i|
    //                    try writer.print("&common.{}.{}.interface,", .{ prefix(i), trimPrefix(i) })
    //                else
    //                    try writer.writeAll("null,"),
    //                else => try writer.writeAll("null,"),
    //            }
    //        }
    //        try writer.writeAll("},");
    //    } else {
    //        try writer.writeAll("null,");
    //    }
    //    try writer.writeAll("},");
    //}

    fn emitField(message: Message, side: Side, writer: anytype) !void {
        try printIdentifier(writer, message.name);
        if (message.args.items.len == 0) {
            try writer.writeAll(": void,");
            return;
        }
        try writer.writeAll(": struct {");
        for (message.args.items) |arg| {
            if (side == .server and arg.kind == .new_id and arg.kind.new_id == null) {
                try writer.writeAll("interface_name: [*:0]const u8, version: u32,");
                try printIdentifier(writer, arg.name);
                try writer.writeAll(": u32");
            } else if (side == .client and arg.kind == .new_id) {
                try printIdentifier(writer, arg.name);
                try writer.writeAll(": *");
                try printAbsolute(.client, writer, arg.kind.new_id.?);
                std.debug.assert(!arg.allow_null);
            } else {
                try printIdentifier(writer, arg.name);
                try writer.writeByte(':');
                // See notes on NULL in doc comment for wl_message in wayland-util.h
                if (side == .client and arg.kind == .object and !arg.allow_null)
                    try writer.writeByte('?');
                try arg.emitType(side, writer);
            }
            try writer.writeByte(',');
        }
        try writer.writeAll("},\n");
    }

    fn emitFn(message: Message, side: Side, writer: anytype, interface: Interface, opcode: usize) !void {
        try writer.writeAll("pub fn ");
        if (side == .server) {
            try writer.writeAll("send");
            try printIdentifier(writer, case(.title, message.name));
        } else {
            try printIdentifier(writer, case(.camel, message.name));
        }
        try writer.writeAll("(_");
        try printIdentifier(writer, trimPrefix(interface.name));
        try writer.writeAll(": *");
        try printIdentifier(writer, case(.title, trimPrefix(interface.name)));
        for (message.args.items) |arg| {
            if (side == .server and arg.kind == .new_id) {
                try writer.writeAll(", _");
                try printIdentifier(writer, arg.name);
                try writer.writeByte(':');
                if (arg.allow_null) try writer.writeByte('?');
                try writer.writeByte('*');
                if (arg.kind.new_id) |iface|
                    try printIdentifier(writer, case(.title, trimPrefix(iface)))
                else
                    try writer.writeAll("server.wl.Resource");
            } else if (side == .client and arg.kind == .new_id) {
                if (arg.kind.new_id == null) try writer.writeAll(", comptime T: type, _version: u32");
            } else {
                try writer.writeAll(", _");
                try printIdentifier(writer, arg.name);
                try writer.writeByte(':');
                try arg.emitType(side, writer);
            }
        }
        if (side == .server or message.kind != .constructor) {
            try writer.writeAll(") void {");
        } else if (message.kind.constructor) |new_iface| {
            try writer.writeAll(") !*");
            try printIdentifier(writer, case(.title, trimPrefix(new_iface)));
            try writer.writeAll("{");
        } else {
            try writer.writeAll(") !*T {");
        }
        if (side == .server)
            try writer.writeAll("const _resource = @ptrCast(*server.wl.Resource,_")
        else
            try writer.writeAll("const _proxy = @ptrCast(*client.wl.Proxy,_");
        try printIdentifier(writer, trimPrefix(interface.name));
        try writer.writeAll(");");
        if (message.args.items.len > 0) {
            try writer.writeAll("var _args = [_]common.Argument{");
            for (message.args.items) |arg| {
                switch (arg.kind) {
                    .int, .uint, .fixed, .string, .array, .fd => {
                        try writer.writeAll(".{ .");
                        try arg.emitSignature(writer);
                        try writer.writeAll(" = ");
                        if (arg.enum_name != null) {
                            try writer.writeAll("switch (@typeInfo(");
                            try arg.emitType(side, writer);

                            // TODO We know the type of the enum at scanning time, but it's
                            //      currently a bit difficult to access it.
                            const c_type = if (arg.kind == .uint) "u32" else "i32";
                            try writer.print(
                                \\ )) {{
                                \\    .Enum => @intCast({s}, @enumToInt(_{s})),
                                \\    .Struct => @bitCast(u32, _{s}),
                                \\    else => unreachable,
                                \\ }}
                            , .{ c_type, arg.name, arg.name });
                        } else {
                            try writer.writeByte('_');
                            try printIdentifier(writer, arg.name);
                        }
                        try writer.writeAll("},");
                    },
                    .object, .new_id => |new_iface| {
                        if (arg.kind == .object or side == .server) {
                            if (arg.allow_null) {
                                try writer.writeAll(".{ .o = @ptrCast(?*common.Object, _");
                            } else {
                                try writer.writeAll(".{ .o = @ptrCast(*common.Object, _");
                            }
                            try printIdentifier(writer, arg.name);
                            try writer.writeAll(") },");
                        } else {
                            if (new_iface == null) {
                                try writer.writeAll(
                                    \\.{ .s = T.getInterface().name },
                                    \\.{ .u = _version },
                                );
                            }
                            try writer.writeAll(".{ .o = null },");
                        }
                    },
                }
            }
            try writer.writeAll("};\n");
        }
        const args = if (message.args.items.len > 0) "&_args" else "null";
        if (side == .server) {
            try writer.print("_resource.postEvent({}, {s});", .{ opcode, args });
        } else switch (message.kind) {
            .normal, .destructor => {
                try writer.print("_proxy.marshal({}, {s});", .{ opcode, args });
                if (message.kind == .destructor) try writer.writeAll("_proxy.destroy();");
            },
            .constructor => |new_iface| {
                if (new_iface) |i| {
                    try writer.writeAll("return @ptrCast(*");
                    try printIdentifier(writer, case(.title, trimPrefix(i)));
                    try writer.print(", try _proxy.marshalConstructor({}, &_args, ", .{opcode});
                    try printIdentifier(writer, case(.title, trimPrefix(i)));
                    try writer.writeAll(".getInterface()));");
                } else {
                    try writer.print("return @ptrCast(*T, try _proxy.marshalConstructorVersioned({}, &_args, T.getInterface(), _version));", .{opcode});
                }
            },
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

    fn parse(allocator: *mem.Allocator, parser: *xml.Parser) !Arg {
        var name: ?[]const u8 = null;
        var kind: ?std.meta.Tag(Type) = null;
        var interface: ?[]const u8 = null;
        var allow_null: ?bool = null;
        var enum_name: ?[]const u8 = null;

        while (parser.next()) |ev| switch (ev) {
            .attribute => |attr| {
                if (mem.eql(u8, attr.name, "name")) {
                    if (name != null) return error.DuplicateName;
                    name = try attr.dupeValue(allocator);
                } else if (mem.eql(u8, attr.name, "type")) {
                    if (kind != null) return error.DuplicateType;
                    kind = std.meta.stringToEnum(std.meta.Tag(Type), try attr.dupeValue(allocator)) orelse
                        return error.InvalidType;
                } else if (mem.eql(u8, attr.name, "interface")) {
                    if (interface != null) return error.DuplicateInterface;
                    interface = try attr.dupeValue(allocator);
                } else if (mem.eql(u8, attr.name, "allow-null")) {
                    if (allow_null != null) return error.DuplicateAllowNull;
                    if (!attr.valueEql("true") and !attr.valueEql("false")) return error.InvalidBoolValue;
                    allow_null = attr.valueEql("true");
                } else if (mem.eql(u8, attr.name, "enum")) {
                    if (enum_name != null) return error.DuplicateEnum;
                    enum_name = try attr.dupeValue(allocator);
                }
            },
            .close_tag => |tag| if (mem.eql(u8, tag, "arg")) {
                return Arg{
                    .name = name orelse return error.MissingName,
                    .kind = switch (kind orelse return error.MissingType) {
                        .object => .{ .object = interface },
                        .new_id => .{ .new_id = interface },
                        .int => .int,
                        .uint => .uint,
                        .fixed => .fixed,
                        .string => .string,
                        .array => .array,
                        .fd => .fd,
                    },
                    .allow_null = allow_null orelse false,
                    .enum_name = enum_name,
                };
            },
            else => {},
        };
        return error.UnexpectedEndOfFile;
    }

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

    fn emitType(arg: Arg, side: Side, writer: anytype) !void {
        switch (arg.kind) {
            .int, .uint => {
                if (arg.enum_name) |name| {
                    if (mem.indexOfScalar(u8, name, '.')) |dot_index| {
                        // Turn a reference like wl_shm.format into common.wl.shm.Format
                        try writer.writeAll("common.");
                        const us_index = mem.indexOfScalar(u8, name, '_') orelse 0;
                        try writer.writeAll(name[0..us_index]);
                        try writer.writeAll(".");
                        try writer.writeAll(name[us_index + 1 .. dot_index + 1]);
                        try writer.writeAll(case(.title, name[dot_index + 1 ..]));
                    } else {
                        try writer.writeAll(case(.title, name));
                    }
                } else if (arg.kind == .int) {
                    try writer.writeAll("i32");
                } else {
                    try writer.writeAll("u32");
                }
            },
            .new_id => try writer.writeAll("u32"),
            .fixed => try writer.writeAll("common.Fixed"),
            .string => {
                if (arg.allow_null) try writer.writeByte('?');
                try writer.writeAll("[*:0]const u8");
            },
            .object => |interface| if (interface) |i| {
                if (arg.allow_null) try writer.writeAll("?*") else try writer.writeByte('*');
                try printAbsolute(side, writer, i);
            } else {
                if (arg.allow_null) try writer.writeByte('?');
                try writer.writeAll("*common.Object");
            },
            .array => {
                if (arg.allow_null) try writer.writeByte('?');
                try writer.writeAll("*common.Array");
            },
            .fd => try writer.writeAll("i32"),
        }
    }
};

const Enum = struct {
    name: []const u8,
    since: u32,
    entries: std.ArrayList(Entry),
    bitfield: bool,

    fn parse(allocator: *mem.Allocator, parser: *xml.Parser) !Enum {
        var name: ?[]const u8 = null;
        var since: ?u32 = null;
        var entries = std.ArrayList(Entry).init(allocator);
        var bitfield: ?bool = null;

        while (parser.next()) |ev| switch (ev) {
            .open_tag => |tag| {
                // TODO: parse description
                if (mem.eql(u8, tag, "entry"))
                    try entries.append(try Entry.parse(allocator, parser));
            },
            .attribute => |attr| {
                if (mem.eql(u8, attr.name, "name")) {
                    if (name != null) return error.DuplicateName;
                    name = try attr.dupeValue(allocator);
                } else if (mem.eql(u8, attr.name, "since")) {
                    if (since != null) return error.DuplicateSince;
                    since = try std.fmt.parseInt(u32, try attr.dupeValue(allocator), 10);
                } else if (mem.eql(u8, attr.name, "bitfield")) {
                    if (bitfield != null) return error.DuplicateBitfield;
                    if (!attr.valueEql("true") and !attr.valueEql("false")) return error.InvalidBoolValue;
                    bitfield = attr.valueEql("true");
                }
            },
            .close_tag => |tag| if (mem.eql(u8, tag, "enum")) {
                return Enum{
                    .name = name orelse return error.MissingName,
                    .since = since orelse 1,
                    .entries = entries,
                    .bitfield = bitfield orelse false,
                };
            },
            else => {},
        };
        return error.UnexpectedEndOfFile;
    }

    fn emit(e: Enum, writer: anytype) !void {
        try writer.writeAll("pub const ");
        try printIdentifier(writer, case(.title, e.name));

        if (e.bitfield) {
            var entries_emitted: u8 = 0;
            try writer.writeAll(" = packed struct {");
            for (e.entries.items) |entry| {
                const value = entry.intValue();
                if (value != 0 and std.math.isPowerOfTwo(value)) {
                    try printIdentifier(writer, entry.name);
                    if (entries_emitted == 0) {
                        // Align the first field to ensure the entire packed
                        // struct matches the alignment of a u32. This allows
                        // using the packed struct as the field of an extern
                        // struct where a u32 is expected.
                        try writer.writeAll(": bool align(@alignOf(u32)) = false,");
                    } else {
                        try writer.writeAll(": bool = false,");
                    }
                    entries_emitted += 1;
                }
            }
            // Pad to 32 bits. Use only bools to avoid zig stage1 packed
            // struct bugs.
            while (entries_emitted < 32) : (entries_emitted += 1) {
                try writer.print("_paddding{}: bool = false,\n", .{entries_emitted});
            }

            // Emit the normal C abi enum as well as it may be needed to interface
            // with C code.
            try writer.writeAll("pub const Enum ");
        }

        try writer.writeAll(" = extern enum(c_int) {");
        for (e.entries.items) |entry| {
            try printIdentifier(writer, entry.name);
            try writer.print("= {s},", .{entry.value});
        }
        // Always generate non-exhaustive enums to ensure forward compatability.
        // Entries have been added to wl_shm.format without bumping the version.
        try writer.writeAll("_,};\n");

        if (e.bitfield) try writer.writeAll("};\n");
    }
};

const Entry = struct {
    name: []const u8,
    since: u32,
    value: []const u8,

    fn parse(allocator: *mem.Allocator, parser: *xml.Parser) !Entry {
        var name: ?[]const u8 = null;
        var since: ?u32 = null;
        var value: ?[]const u8 = null;

        while (parser.next()) |ev| switch (ev) {
            .attribute => |attr| {
                if (mem.eql(u8, attr.name, "name")) {
                    if (name != null) return error.DuplicateName;
                    name = try attr.dupeValue(allocator);
                } else if (mem.eql(u8, attr.name, "since")) {
                    if (since != null) return error.DuplicateSince;
                    since = try std.fmt.parseInt(u32, try attr.dupeValue(allocator), 10);
                } else if (mem.eql(u8, attr.name, "value")) {
                    if (value != null) return error.DuplicateName;
                    value = try attr.dupeValue(allocator);
                }
            },
            .close_tag => |tag| if (mem.eql(u8, tag, "entry")) {
                return Entry{
                    .name = name orelse return error.MissingName,
                    .since = since orelse 1,
                    .value = value orelse return error.MissingValue,
                };
            },
            else => {},
        };
        return error.UnexpectedEndOfFile;
    }

    // Return numeric value of enum entry. Can be base 10 and hexadecimal notation.
    fn intValue(e: Entry) u32 {
        return std.fmt.parseInt(u32, e.value, 10) catch blk: {
            const index = mem.indexOfScalar(u8, e.value, 'x').?;
            break :blk std.fmt.parseInt(u32, e.value[index + 1 ..], 16) catch @panic("Can't parse enum entry.");
        };
    }
};

fn prefix(s: []const u8) ?[]const u8 {
    return s[0 .. mem.indexOfScalar(u8, s, '_') orelse return null];
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

fn printAbsolute(side: Side, writer: anytype, interface: []const u8) !void {
    try writer.writeAll(@tagName(side));
    try writer.writeByte('.');
    try printIdentifier(writer, prefix(interface) orelse return error.MissingPrefix);
    try writer.writeByte('.');
    try printIdentifier(writer, case(.title, trimPrefix(interface)));
}

fn printIdentifier(writer: anytype, identifier: []const u8) !void {
    if (isValidIdentifier(identifier))
        try writer.writeAll(identifier)
    else
        try writer.print("@\"{s}\"", .{identifier});
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
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const protocol = try Protocol.parseXML(&arena.allocator, @embedFile("../protocol/wayland.xml"));

    try testing.expectEqualSlices(u8, "wayland", protocol.name);
    try testing.expectEqual(@as(usize, 22), protocol.interfaces.items.len);

    {
        const wl_display = protocol.interfaces.items[0];
        try testing.expectEqualSlices(u8, "wl_display", wl_display.name);
        try testing.expectEqual(@as(u32, 1), wl_display.version);
        try testing.expectEqual(@as(usize, 2), wl_display.requests.items.len);
        try testing.expectEqual(@as(usize, 2), wl_display.events.items.len);
        try testing.expectEqual(@as(usize, 1), wl_display.enums.items.len);

        {
            const sync = wl_display.requests.items[0];
            try testing.expectEqualSlices(u8, "sync", sync.name);
            try testing.expectEqual(@as(u32, 1), sync.since);
            try testing.expectEqual(@as(usize, 1), sync.args.items.len);
            {
                const callback = sync.args.items[0];
                try testing.expectEqualSlices(u8, "callback", callback.name);
                try testing.expect(callback.kind == .new_id);
                try testing.expectEqualSlices(u8, "wl_callback", callback.kind.new_id.?);
                try testing.expectEqual(false, callback.allow_null);
                try testing.expectEqual(@as(?[]const u8, null), callback.enum_name);
            }
            try testing.expect(sync.kind == .constructor);
        }

        {
            const error_event = wl_display.events.items[0];
            try testing.expectEqualSlices(u8, "error", error_event.name);
            try testing.expectEqual(@as(u32, 1), error_event.since);
            try testing.expectEqual(@as(usize, 3), error_event.args.items.len);
            {
                const object_id = error_event.args.items[0];
                try testing.expectEqualSlices(u8, "object_id", object_id.name);
                try testing.expectEqual(Arg.Type{ .object = null }, object_id.kind);
                try testing.expectEqual(false, object_id.allow_null);
                try testing.expectEqual(@as(?[]const u8, null), object_id.enum_name);
            }
            {
                const code = error_event.args.items[1];
                try testing.expectEqualSlices(u8, "code", code.name);
                try testing.expectEqual(Arg.Type.uint, code.kind);
                try testing.expectEqual(false, code.allow_null);
                try testing.expectEqual(@as(?[]const u8, null), code.enum_name);
            }
            {
                const message = error_event.args.items[2];
                try testing.expectEqualSlices(u8, "message", message.name);
                try testing.expectEqual(Arg.Type.string, message.kind);
                try testing.expectEqual(false, message.allow_null);
                try testing.expectEqual(@as(?[]const u8, null), message.enum_name);
            }
        }

        {
            const error_enum = wl_display.enums.items[0];
            try testing.expectEqualSlices(u8, "error", error_enum.name);
            try testing.expectEqual(@as(u32, 1), error_enum.since);
            try testing.expectEqual(@as(usize, 4), error_enum.entries.items.len);
            {
                const invalid_object = error_enum.entries.items[0];
                try testing.expectEqualSlices(u8, "invalid_object", invalid_object.name);
                try testing.expectEqual(@as(u32, 1), invalid_object.since);
                try testing.expectEqualSlices(u8, "0", invalid_object.value);
            }
            {
                const invalid_method = error_enum.entries.items[1];
                try testing.expectEqualSlices(u8, "invalid_method", invalid_method.name);
                try testing.expectEqual(@as(u32, 1), invalid_method.since);
                try testing.expectEqualSlices(u8, "1", invalid_method.value);
            }
            {
                const no_memory = error_enum.entries.items[2];
                try testing.expectEqualSlices(u8, "no_memory", no_memory.name);
                try testing.expectEqual(@as(u32, 1), no_memory.since);
                try testing.expectEqualSlices(u8, "2", no_memory.value);
            }
            {
                const implementation = error_enum.entries.items[3];
                try testing.expectEqualSlices(u8, "implementation", implementation.name);
                try testing.expectEqual(@as(u32, 1), implementation.since);
                try testing.expectEqualSlices(u8, "3", implementation.value);
            }
            try testing.expectEqual(false, error_enum.bitfield);
        }
    }

    {
        const wl_data_offer = protocol.interfaces.items[7];
        try testing.expectEqualSlices(u8, "wl_data_offer", wl_data_offer.name);
        try testing.expectEqual(@as(u32, 3), wl_data_offer.version);
        try testing.expectEqual(@as(usize, 5), wl_data_offer.requests.items.len);
        try testing.expectEqual(@as(usize, 3), wl_data_offer.events.items.len);
        try testing.expectEqual(@as(usize, 1), wl_data_offer.enums.items.len);

        {
            const accept = wl_data_offer.requests.items[0];
            try testing.expectEqualSlices(u8, "accept", accept.name);
            try testing.expectEqual(@as(u32, 1), accept.since);
            try testing.expectEqual(@as(usize, 2), accept.args.items.len);
            {
                const serial = accept.args.items[0];
                try testing.expectEqualSlices(u8, "serial", serial.name);
                try testing.expectEqual(Arg.Type.uint, serial.kind);
                try testing.expectEqual(false, serial.allow_null);
            }
            {
                const mime_type = accept.args.items[1];
                try testing.expectEqualSlices(u8, "mime_type", mime_type.name);
                try testing.expectEqual(Arg.Type.string, mime_type.kind);
                try testing.expectEqual(true, mime_type.allow_null);
            }
        }
    }
}
