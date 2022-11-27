const std = @import("std");
const assert = std.debug.assert;
const fs = std.fs;
const mem = std.mem;
const os = std.os;
const fmtId = std.zig.fmtId;

const log = std.log.scoped(.@"zig-wayland");

const xml = @import("xml.zig");

const gpa = general_purpose_allocator.allocator();
var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};

pub const Target = struct {
    /// Name of the target global interface
    name: []const u8,
    /// Interface version for which to generate code.
    /// If the version found in the protocol xml is less than this version,
    /// an error will be printed and code generation will fail.
    /// This version applies to interfaces that may be created through the
    /// global interface as well.
    version: u32,
};

pub fn scan(
    root_dir: fs.Dir,
    out_dir: fs.Dir,
    protocols: []const []const u8,
    targets: []const Target,
) !void {
    defer assert(!general_purpose_allocator.deinit());

    const wayland_file = try out_dir.createFile("wayland.zig", .{});
    try wayland_file.writeAll(
        \\pub const client = @import("client.zig");
        \\pub const server = @import("server.zig");
    );
    defer wayland_file.close();

    var scanner = try Scanner.init(targets);
    defer scanner.deinit();

    for (protocols) |xml_path| {
        try scanner.scanProtocol(root_dir, out_dir, xml_path);
    }

    if (scanner.remaining_targets.items.len != 0) {
        log.err("requested global interface '{s}' not found in provided protocol xml", .{
            scanner.remaining_targets.items[0].name,
        });
        os.exit(1);
    }

    {
        const client_core_file = try out_dir.createFile("wayland_client_core.zig", .{});
        defer client_core_file.close();
        try client_core_file.writeAll(@embedFile("wayland_client_core.zig"));

        const client_file = try out_dir.createFile("client.zig", .{});
        defer client_file.close();
        const writer = client_file.writer();

        var iter = scanner.client.iterator();
        while (iter.next()) |entry| {
            try writer.print("pub const {s} = struct {{", .{entry.key_ptr.*});
            if (mem.eql(u8, entry.key_ptr.*, "wl"))
                try writer.writeAll("pub usingnamespace @import(\"wayland_client_core.zig\");\n");
            for (entry.value_ptr.items) |generated_file|
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
            try writer.print("pub const {s} = struct {{", .{entry.key_ptr.*});
            if (mem.eql(u8, entry.key_ptr.*, "wl"))
                try writer.writeAll("pub usingnamespace @import(\"wayland_server_core.zig\");\n");
            for (entry.value_ptr.items) |generated_file|
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
            try writer.print("pub const {s} = struct {{", .{entry.key_ptr.*});
            for (entry.value_ptr.items) |generated_file|
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
    const Map = std.StringArrayHashMap(std.ArrayListUnmanaged([]const u8));
    client: Map = Map.init(gpa),
    server: Map = Map.init(gpa),
    common: Map = Map.init(gpa),

    remaining_targets: std.ArrayListUnmanaged(Target),

    fn init(targets: []const Target) !Scanner {
        return Scanner{
            .remaining_targets = .{
                .items = try gpa.dupe(Target, targets),
                .capacity = targets.len,
            },
        };
    }

    fn deinit(scanner: *Scanner) void {
        deinit_map(&scanner.client);
        deinit_map(&scanner.server);
        deinit_map(&scanner.common);

        scanner.remaining_targets.deinit(gpa);
    }

    fn deinit_map(map: *Map) void {
        for (map.keys()) |namespace| gpa.free(namespace);
        for (map.values()) |*list| {
            for (list.items) |file_name| gpa.free(file_name);
            list.deinit(gpa);
        }
        map.deinit();
    }

    fn scanProtocol(scanner: *Scanner, root_dir: fs.Dir, out_dir: fs.Dir, xml_path: []const u8) !void {
        const xml_file = try root_dir.openFile(xml_path, .{});
        defer xml_file.close();

        var arena = std.heap.ArenaAllocator.init(gpa);
        defer arena.deinit();

        const xml_bytes = try xml_file.readToEndAlloc(arena.allocator(), 512 * 4096);
        const protocol = Protocol.parseXML(arena.allocator(), xml_bytes) catch |err| {
            log.err("failed to parse {s}: {s}", .{ xml_path, @errorName(err) });
            os.exit(1);
        };

        var buffered_writer: std.io.BufferedWriter(4096, std.fs.File.Writer) = .{
            .unbuffered_writer = undefined,
        };
        {
            const client_filename = try mem.concat(gpa, u8, &[_][]const u8{ protocol.name, "_client.zig" });
            const client_file = try out_dir.createFile(client_filename, .{});
            defer client_file.close();

            buffered_writer.unbuffered_writer = client_file.writer();

            try protocol.emit(.client, scanner.remaining_targets.items, buffered_writer.writer());

            const gop = try scanner.client.getOrPutValue(protocol.namespace, .{});
            if (!gop.found_existing) gop.key_ptr.* = try gpa.dupe(u8, protocol.namespace);
            try gop.value_ptr.append(gpa, client_filename);

            try buffered_writer.flush();
        }

        {
            const server_filename = try mem.concat(gpa, u8, &[_][]const u8{ protocol.name, "_server.zig" });
            const server_file = try out_dir.createFile(server_filename, .{});
            defer server_file.close();

            buffered_writer.unbuffered_writer = server_file.writer();

            try protocol.emit(.server, scanner.remaining_targets.items, buffered_writer.writer());

            const gop = try scanner.server.getOrPutValue(protocol.namespace, .{});
            if (!gop.found_existing) gop.key_ptr.* = try gpa.dupe(u8, protocol.namespace);
            try gop.value_ptr.append(gpa, server_filename);

            try buffered_writer.flush();
        }

        {
            const common_filename = try mem.concat(gpa, u8, &[_][]const u8{ protocol.name, "_common.zig" });
            const common_file = try out_dir.createFile(common_filename, .{});
            defer common_file.close();

            buffered_writer.unbuffered_writer = common_file.writer();

            try protocol.emitCommon(scanner.remaining_targets.items, buffered_writer.writer());

            const gop = try scanner.common.getOrPutValue(protocol.namespace, .{});
            if (!gop.found_existing) gop.key_ptr.* = try gpa.dupe(u8, protocol.namespace);
            try gop.value_ptr.append(gpa, common_filename);

            try buffered_writer.flush();
        }

        {
            var i: usize = 0;
            outer: while (i < scanner.remaining_targets.items.len) {
                const target = scanner.remaining_targets.items[i];
                for (protocol.globals) |global| {
                    if (mem.eql(u8, target.name, global.interface.name)) {
                        // We check this in emitClient() which is called first.
                        assert(global.interface.version >= target.version);
                        _ = scanner.remaining_targets.swapRemove(i);
                        continue :outer;
                    }
                }
                i += 1;
            }
        }
    }
};

/// All data in this struct is immutable after creation in parse().
const Protocol = struct {
    const Global = struct {
        interface: Interface,
        children: []const Interface,
    };

    name: []const u8,
    namespace: []const u8,
    copyright: ?[]const u8,
    toplevel_description: ?[]const u8,

    version_locked_interfaces: []const Interface,
    globals: []const Global,

    fn parseXML(arena: mem.Allocator, xml_bytes: []const u8) !Protocol {
        var parser = xml.Parser.init(xml_bytes);
        while (parser.next()) |ev| switch (ev) {
            .open_tag => |tag| if (mem.eql(u8, tag, "protocol")) return parse(arena, &parser),
            else => {},
        };
        return error.UnexpectedEndOfFile;
    }

    fn parse(arena: mem.Allocator, parser: *xml.Parser) !Protocol {
        var name: ?[]const u8 = null;
        var copyright: ?[]const u8 = null;
        var toplevel_description: ?[]const u8 = null;
        var version_locked_interfaces = std.ArrayList(Interface).init(gpa);
        defer version_locked_interfaces.deinit();
        var interfaces = std.StringArrayHashMap(Interface).init(gpa);
        defer interfaces.deinit();

        while (parser.next()) |ev| switch (ev) {
            .open_tag => |tag| {
                if (mem.eql(u8, tag, "copyright")) {
                    if (copyright != null)
                        return error.DuplicateCopyright;
                    const e = parser.next() orelse return error.UnexpectedEndOfFile;
                    switch (e) {
                        .character_data => |data| copyright = try arena.dupe(u8, data),
                        else => return error.BadCopyright,
                    }
                } else if (mem.eql(u8, tag, "description")) {
                    if (toplevel_description != null)
                        return error.DuplicateToplevelDescription;
                    while (parser.next()) |e| {
                        switch (e) {
                            .character_data => |data| {
                                toplevel_description = try arena.dupe(u8, data);
                                break;
                            },
                            .attribute => continue,
                            else => return error.BadToplevelDescription,
                        }
                    } else {
                        return error.UnexpectedEndOfFile;
                    }
                } else if (mem.eql(u8, tag, "interface")) {
                    const interface = try Interface.parse(arena, parser);
                    if (Interface.version_locked(interface.name)) {
                        try version_locked_interfaces.append(interface);
                    } else {
                        const gop = try interfaces.getOrPut(interface.name);
                        if (gop.found_existing) return error.DuplicateInterfaceName;
                        gop.value_ptr.* = interface;
                    }
                }
            },
            .attribute => |attr| if (mem.eql(u8, attr.name, "name")) {
                if (name != null) return error.DuplicateName;
                name = try attr.dupeValue(arena);
            },
            .close_tag => |tag| if (mem.eql(u8, tag, "protocol")) {
                if (interfaces.count() == 0) return error.NoInterfaces;

                const globals = try find_globals(arena, interfaces);
                if (globals.len == 0) return error.NoGlobals;

                const namespace = prefix(interfaces.values()[0].name) orelse return error.NoNamespace;
                for (interfaces.values()) |interface| {
                    const other = prefix(interface.name) orelse return error.NoNamespace;
                    if (!mem.eql(u8, namespace, other)) return error.InconsistentNamespaces;
                }

                return Protocol{
                    .name = name orelse return error.MissingName,
                    .namespace = namespace,

                    // Missing copyright or toplevel description is bad style, but not illegal.
                    .copyright = copyright,
                    .toplevel_description = toplevel_description,
                    .version_locked_interfaces = try arena.dupe(Interface, version_locked_interfaces.items),
                    .globals = globals,
                };
            },
            else => {},
        };
        return error.UnexpectedEndOfFile;
    }

    fn find_globals(arena: mem.Allocator, interfaces: std.StringArrayHashMap(Interface)) ![]const Global {
        var non_globals = std.StringHashMap(void).init(gpa);
        defer non_globals.deinit();

        for (interfaces.values()) |interface| {
            assert(!Interface.version_locked(interface.name));
            for (interface.requests) |message| {
                if (message.kind == .constructor) {
                    if (message.kind.constructor) |child_interface_name| {
                        try non_globals.put(child_interface_name, {});
                    }
                }
            }
            for (interface.events) |message| {
                if (message.kind == .constructor) {
                    if (message.kind.constructor) |child_interface_name| {
                        try non_globals.put(child_interface_name, {});
                    }
                }
            }
        }

        var globals = std.ArrayList(Global).init(gpa);
        defer globals.deinit();

        for (interfaces.values()) |interface| {
            if (!non_globals.contains(interface.name)) {
                var children = std.StringArrayHashMap(Interface).init(gpa);
                defer children.deinit();

                try find_children(interface, interfaces, &children);

                try globals.append(.{
                    .interface = interface,
                    .children = try arena.dupe(Interface, children.values()),
                });
            }
        }

        return arena.dupe(Global, globals.items);
    }

    fn find_children(
        parent: Interface,
        interfaces: std.StringArrayHashMap(Interface),
        children: *std.StringArrayHashMap(Interface),
    ) error{ OutOfMemory, InvalidInterface }!void {
        for ([_][]const Message{ parent.requests, parent.events }) |messages| {
            for (messages) |message| {
                if (message.kind == .constructor) {
                    if (message.kind.constructor) |child_name| {
                        if (Interface.version_locked(child_name)) continue;

                        const child = interfaces.get(child_name) orelse {
                            log.err("interface '{s}' constructed by message '{s}' not defined in the protocol and not wl_callback or wl_buffer", .{
                                child_name,
                                message.name,
                            });
                            return error.InvalidInterface;
                        };
                        try children.put(child_name, child);
                        try find_children(child, interfaces, children);
                    }
                }
            }
        }
    }

    fn emitCopyrightAndToplevelDescription(protocol: Protocol, writer: anytype) !void {
        try writer.writeAll("// Generated by zig-wayland\n\n");
        if (protocol.copyright) |copyright| {
            var it = mem.split(u8, copyright, "\n");
            while (it.next()) |line| {
                try writer.print("// {s}\n", .{mem.trim(u8, line, &std.ascii.spaces)});
            }
            try writer.writeByte('\n');
        }
        if (protocol.toplevel_description) |toplevel_description| {
            var it = mem.split(u8, toplevel_description, "\n");
            while (it.next()) |line| {
                try writer.print("// {s}\n", .{mem.trim(u8, line, &std.ascii.spaces)});
            }
            try writer.writeByte('\n');
        }
    }

    fn emit(protocol: Protocol, side: Side, targets: []const Target, writer: anytype) !void {
        try protocol.emitCopyrightAndToplevelDescription(writer);
        switch (side) {
            .client => try writer.writeAll(
                \\const std = @import("std");
                \\const os = std.os;
                \\const client = @import("wayland.zig").client;
                \\const common = @import("common.zig");
            ),
            .server => try writer.writeAll(
                \\const os = @import("std").os;
                \\const server = @import("wayland.zig").server;
                \\const common = @import("common.zig");
            ),
        }

        for (protocol.version_locked_interfaces) |interface| {
            assert(interface.version == 1);
            try interface.emit(side, 1, protocol.namespace, writer);
        }

        for (targets) |target| {
            for (protocol.globals) |global| {
                if (mem.eql(u8, target.name, global.interface.name)) {
                    if (global.interface.version < target.version) {
                        log.err("requested {s} version {d} but only version {d} is available in provided xml", .{
                            target.name,
                            target.version,
                            global.interface.version,
                        });
                        os.exit(1);
                    }
                    try global.interface.emit(side, target.version, protocol.namespace, writer);
                    for (global.children) |child| {
                        try child.emit(side, target.version, protocol.namespace, writer);
                    }
                }
            }
        }
    }

    fn emitCommon(protocol: Protocol, targets: []const Target, writer: anytype) !void {
        try protocol.emitCopyrightAndToplevelDescription(writer);
        try writer.writeAll(
            \\const common = @import("common.zig");
        );

        for (protocol.version_locked_interfaces) |interface| {
            assert(interface.version == 1);
            try interface.emitCommon(1, writer);
        }

        for (targets) |target| {
            for (protocol.globals) |global| {
                if (mem.eql(u8, target.name, global.interface.name)) {
                    // We check this in emitClient() which is called first.
                    assert(global.interface.version >= target.version);

                    try global.interface.emitCommon(target.version, writer);
                    for (global.children) |child| {
                        try child.emitCommon(target.version, writer);
                    }
                }
            }
        }
    }
};

/// All data in this struct is immutable after creation in parse().
const Interface = struct {
    name: []const u8,
    version: u32,
    requests: []const Message,
    events: []const Message,
    enums: []const Enum,

    // These interfaces are special in that their version may never be increased.
    // That is, they are pinned to version 1 forever. They also may break the
    // normally required tree object creation hierarchy.
    const version_locked_interfaces = std.ComptimeStringMap(void, .{
        .{"wl_display"},
        .{"wl_registry"},
        .{"wl_callback"},
        .{"wl_buffer"},
    });
    fn version_locked(interface_name: []const u8) bool {
        return version_locked_interfaces.has(interface_name);
    }

    fn parse(arena: mem.Allocator, parser: *xml.Parser) !Interface {
        var name: ?[]const u8 = null;
        var version: ?u32 = null;
        var requests = std.ArrayList(Message).init(gpa);
        defer requests.deinit();
        var events = std.ArrayList(Message).init(gpa);
        defer events.deinit();
        var enums = std.ArrayList(Enum).init(gpa);
        defer enums.deinit();

        while (parser.next()) |ev| switch (ev) {
            .open_tag => |tag| {
                // TODO: parse description
                if (mem.eql(u8, tag, "request"))
                    try requests.append(try Message.parse(arena, parser))
                else if (mem.eql(u8, tag, "event"))
                    try events.append(try Message.parse(arena, parser))
                else if (mem.eql(u8, tag, "enum"))
                    try enums.append(try Enum.parse(arena, parser));
            },
            .attribute => |attr| {
                if (mem.eql(u8, attr.name, "name")) {
                    if (name != null) return error.DuplicateName;
                    name = try attr.dupeValue(arena);
                } else if (mem.eql(u8, attr.name, "version")) {
                    if (version != null) return error.DuplicateVersion;
                    version = try std.fmt.parseInt(u32, try attr.dupeValue(arena), 10);
                }
            },
            .close_tag => |tag| if (mem.eql(u8, tag, "interface")) {
                return Interface{
                    .name = name orelse return error.MissingName,
                    .version = version orelse return error.MissingVersion,
                    .requests = try arena.dupe(Message, requests.items),
                    .events = try arena.dupe(Message, events.items),
                    .enums = try arena.dupe(Enum, enums.items),
                };
            },
            else => {},
        };
        return error.UnexpectedEndOfFile;
    }

    fn emit(interface: Interface, side: Side, target_version: u32, namespace: []const u8, writer: anytype) !void {
        try writer.print(
            \\pub const {[type]} = opaque {{
            \\ pub const generated_version = {[version]};
            \\ pub const getInterface = common.{[namespace]}.{[interface]}.getInterface;
        , .{
            .@"type" = titleCaseTrim(interface.name),
            .version = std.math.min(interface.version, target_version),
            .namespace = fmtId(namespace),
            .interface = fmtId(trimPrefix(interface.name)),
        });

        for (interface.enums) |e| {
            if (e.since <= target_version) {
                try writer.print("pub const {[type]} = common.{[namespace]}.{[interface]}.{[type]};\n", .{
                    .@"type" = titleCase(e.name),
                    .namespace = fmtId(namespace),
                    .interface = fmtId(trimPrefix(interface.name)),
                });
            }
        }

        if (side == .client) {
            try writer.print(
                \\pub fn setQueue(_{[interface]}: *{[type]}, _queue: *client.wl.EventQueue) void {{
                \\    const _proxy = @ptrCast(*client.wl.Proxy, _{[interface]});
                \\    _proxy.setQueue(_queue);
                \\}}
            , .{
                .interface = fmtId(trimPrefix(interface.name)),
                .@"type" = titleCaseTrim(interface.name),
            });

            const has_event = for (interface.events) |event| {
                if (event.since <= target_version) break true;
            } else false;

            if (has_event) {
                try writer.writeAll("pub const Event = union(enum) {");
                for (interface.events) |event| {
                    if (event.since <= target_version) {
                        try event.emitField(.client, writer);
                    }
                }
                try writer.writeAll("};\n");
                try writer.print(
                    \\pub inline fn setListener(
                    \\    _{[interface]}: *{[type]},
                    \\    comptime T: type,
                    \\    _listener: *const fn ({[interface]}: *{[type]}, event: Event, data: T) void,
                    \\    _data: T,
                    \\) void {{
                    \\    const _proxy = @ptrCast(*client.wl.Proxy, _{[interface]});
                    \\    const _mut_data = @intToPtr(?*anyopaque, @ptrToInt(_data));
                    \\    _proxy.addDispatcher(common.Dispatcher({[type]}, T).dispatcher, _listener, _mut_data);
                    \\}}
                , .{
                    .interface = fmtId(trimPrefix(interface.name)),
                    .@"type" = titleCaseTrim(interface.name),
                });
            }

            var has_destroy = false;
            for (interface.requests) |request, opcode| {
                if (request.since <= target_version) {
                    if (mem.eql(u8, request.name, "destroy")) has_destroy = true;
                    try request.emitFn(side, writer, interface, opcode);
                }
            }

            if (mem.eql(u8, interface.name, "wl_display")) {
                try writer.writeAll(@embedFile("client_display_functions.zig"));
            } else if (!has_destroy) {
                try writer.print(
                    \\pub fn destroy(_{[interface]}: *{[type]}) void {{
                    \\    const _proxy = @ptrCast(*client.wl.Proxy, _{[interface]});
                    \\    _proxy.destroy();
                    \\}}
                , .{
                    .interface = fmtId(trimPrefix(interface.name)),
                    .@"type" = titleCaseTrim(interface.name),
                });
            }
        } else {
            try writer.print(
                \\pub fn create(_client: *server.wl.Client, _version: u32, _id: u32) !*{(tc)} {{
                \\    return @ptrCast(*{[type]}, try server.wl.Resource.create(_client, {[type]}, _version, _id));
                \\}}pub fn destroy(_{[interface]}: *{[type]}) void {{
                \\    return @ptrCast(*server.wl.Resource, _{[interface]}).destroy();
                \\}}pub fn fromLink(_link: *server.wl.list.Link) *{[type]} {{
                \\    return @ptrCast(*{[type]}, server.wl.Resource.fromLink(_link));
                \\}}
            , .{
                .@"type" = titleCaseTrim(interface.name),
                .interface = fmtId(trimPrefix(interface.name)),
            });

            for ([_][2][]const u8{
                .{ "getLink", "*server.wl.list.Link" },
                .{ "getClient", "*server.wl.Client" },
                .{ "getId", "u32" },
                .{ "getVersion", "u32" },
                .{ "postNoMemory", "void" },
            }) |func|
                try writer.print(
                    \\pub fn {[function]}(_{[interface]}: *{[type]}) {[return_type]} {{
                    \\    return @ptrCast(*server.wl.Resource, _{[interface]}).{[function]}();
                    \\}}
                , .{
                    .function = camelCase(func[0]),
                    .interface = fmtId(trimPrefix(interface.name)),
                    .@"type" = titleCaseTrim(interface.name),
                    .return_type = camelCase(func[1]),
                });

            const has_error = for (interface.enums) |e| {
                if (mem.eql(u8, e.name, "error")) break true;
            } else false;
            if (has_error) {
                try writer.print(
                    \\pub fn postError({[interface]}: *{[type]}, _err: Error, _message: [*:0]const u8) void {{
                    \\    return @ptrCast(*server.wl.Resource, {[interface]}).postError(@intCast(u32, @enumToInt(_err)), _message);
                    \\}}
                , .{
                    .interface = fmtId(trimPrefix(interface.name)),
                    .@"type" = titleCaseTrim(interface.name),
                });
            }

            const has_request = for (interface.requests) |request| {
                if (request.since <= target_version) break true;
            } else false;

            if (has_request) {
                try writer.writeAll("pub const Request = union(enum) {");
                for (interface.requests) |request| {
                    if (request.since <= target_version) {
                        try request.emitField(.server, writer);
                    }
                }
                try writer.writeAll("};\n");
                @setEvalBranchQuota(2500);
                try writer.print(
                    \\pub inline fn setHandler(
                    \\    _{[interface]}: *{[type]},
                    \\    comptime T: type,
                    \\    handle_request: *const fn (_{[interface]}: *{[type]}, request: Request, data: T) void,
                    \\    comptime handle_destroy: ?fn (_{[interface]}: *{[type]}, data: T) void,
                    \\    _data: T,
                    \\) void {{
                    \\    const _resource = @ptrCast(*server.wl.Resource, _{[interface]});
                    \\    _resource.setDispatcher(
                    \\        common.Dispatcher({[type]}, T).dispatcher,
                    \\        handle_request,
                    \\        @intToPtr(?*anyopaque, @ptrToInt(_data)),
                    \\        if (handle_destroy) |_handler| struct {{
                    \\            fn _wrapper(__resource: *server.wl.Resource) callconv(.C) void {{
                    \\                @call(.{{ .modifier = .always_inline }}, _handler, .{{
                    \\                    @ptrCast(*{[type]}, __resource),
                    \\                    @intToPtr(T, @ptrToInt(__resource.getUserData())),
                    \\                }});
                    \\            }}
                    \\        }}._wrapper else null,
                    \\    );
                    \\}}
                , .{
                    .interface = fmtId(trimPrefix(interface.name)),
                    .@"type" = titleCaseTrim(interface.name),
                });
            } else {
                try writer.print(
                    \\pub inline fn setHandler(
                    \\    _{[interface]}: *{[type]},
                    \\    comptime T: type,
                    \\    comptime handle_destroy: ?fn (_{[interface]}: *{[type]}, data: T) void,
                    \\    _data: T,
                    \\) void {{
                    \\    const _resource = @ptrCast(*server.wl.Resource, _{[interface]});
                    \\    _resource.setDispatcher(
                    \\        null,
                    \\        null,
                    \\        @intToPtr(?*anyopaque, @ptrToInt(_data)),
                    \\        if (handle_destroy) |_handler| struct {{
                    \\            fn _wrapper(__resource: *server.wl.Resource) callconv(.C) void {{
                    \\                @call(.{{ .modifier = .always_inline }}, _handler, .{{
                    \\                    @ptrCast(*{[type]}, __resource),
                    \\                    @intToPtr(T, @ptrToInt(__resource.getUserData())),
                    \\                }});
                    \\            }}
                    \\        }}._wrapper else null,
                    \\    );
                    \\}}
                , .{
                    .interface = fmtId(trimPrefix(interface.name)),
                    .@"type" = titleCaseTrim(interface.name),
                });
            }

            for (interface.events) |event, opcode|
                try event.emitFn(side, writer, interface, opcode);
        }

        try writer.writeAll("};\n");
    }

    fn emitCommon(interface: Interface, target_version: u32, writer: anytype) !void {
        try writer.print("pub const {}", .{fmtId(trimPrefix(interface.name))});

        // TODO: stop linking libwayland generated interface structs when
        // https://github.com/ziglang/zig/issues/131 is implemented

        try writer.print(
            \\ = struct {{
            \\ extern const {[interface]s}_interface: common.Interface;
            \\ pub inline fn getInterface() *const common.Interface {{
            \\  return &{[interface]s}_interface;
            \\ }}
        , .{ .interface = interface.name });

        for (interface.enums) |e| {
            if (e.since <= target_version) {
                try e.emit(target_version, writer);
            }
        }
        try writer.writeAll("};");
    }
};

/// All data in this struct is immutable after creation in parse().
const Message = struct {
    name: []const u8,
    since: u32,
    args: []const Arg,
    kind: union(enum) {
        normal: void,
        constructor: ?[]const u8,
        destructor: void,
    },

    fn parse(arena: mem.Allocator, parser: *xml.Parser) !Message {
        var name: ?[]const u8 = null;
        var since: ?u32 = null;
        var args = std.ArrayList(Arg).init(gpa);
        defer args.deinit();
        var destructor = false;

        while (parser.next()) |ev| switch (ev) {
            .open_tag => |tag| {
                // TODO: parse description
                if (mem.eql(u8, tag, "arg"))
                    try args.append(try Arg.parse(arena, parser));
            },
            .attribute => |attr| {
                if (mem.eql(u8, attr.name, "name")) {
                    if (name != null) return error.DuplicateName;
                    name = try attr.dupeValue(arena);
                } else if (mem.eql(u8, attr.name, "since")) {
                    if (since != null) return error.DuplicateSince;
                    since = try std.fmt.parseInt(u32, try attr.dupeValue(arena), 10);
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
                    .args = try arena.dupe(Arg, args.items),
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

    fn emitField(message: Message, side: Side, writer: anytype) !void {
        try writer.print("{s}", .{fmtId(message.name)});
        if (message.args.len == 0) {
            try writer.writeAll(": void,");
            return;
        }
        try writer.writeAll(": struct {");
        for (message.args) |arg| {
            if (side == .server and arg.kind == .new_id and arg.kind.new_id == null) {
                try writer.print("interface_name: [*:0]const u8, version: u32,{}: u32", .{fmtId(arg.name)});
            } else if (side == .client and arg.kind == .new_id) {
                try writer.print("{}: *", .{fmtId(arg.name)});
                try printAbsolute(.client, writer, arg.kind.new_id.?);
                std.debug.assert(!arg.allow_null);
            } else {
                try writer.print("{}:", .{fmtId(arg.name)});
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
            try writer.print("send{}", .{titleCase(message.name)});
        } else {
            try writer.print("{}", .{camelCase(message.name)});
        }
        try writer.print("(_{}: *{}", .{
            fmtId(trimPrefix(interface.name)),
            titleCaseTrim(interface.name),
        });
        for (message.args) |arg| {
            if (side == .server and arg.kind == .new_id) {
                try writer.print(", _{s}:", .{arg.name});
                if (arg.allow_null) try writer.writeByte('?');
                try writer.writeByte('*');
                if (arg.kind.new_id) |iface| {
                    try printAbsolute(side, writer, iface);
                } else {
                    try writer.writeAll("server.wl.Resource");
                }
            } else if (side == .client and arg.kind == .new_id) {
                if (arg.kind.new_id == null) try writer.writeAll(", comptime T: type, _version: u32");
            } else {
                try writer.print(", _{s}:", .{arg.name});
                try arg.emitType(side, writer);
            }
        }
        if (side == .server or message.kind != .constructor) {
            try writer.writeAll(") void {");
        } else if (message.kind.constructor) |new_iface| {
            try writer.writeAll(") !*");
            try printAbsolute(side, writer, new_iface);
            try writer.writeByte('{');
        } else {
            try writer.writeAll(") !*T {");
        }
        if (side == .server) {
            try writer.writeAll("const _resource = @ptrCast(*server.wl.Resource,_");
        } else {
            // wl_registry.bind for example needs special handling
            if (message.kind == .constructor and message.kind.constructor == null) {
                try writer.writeAll("const version_to_construct = std.math.min(T.generated_version, _version);");
            }
            try writer.writeAll("const _proxy = @ptrCast(*client.wl.Proxy,_");
        }
        try writer.print("{});", .{fmtId(trimPrefix(interface.name))});
        if (message.args.len > 0) {
            try writer.writeAll("var _args = [_]common.Argument{");
            for (message.args) |arg| {
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
                                \\    .Enum => @intCast({[ct]s}, @enumToInt(_{[an]})),
                                \\    .Struct => @bitCast(u32, _{[an]}),
                                \\    else => unreachable,
                                \\ }}
                            , .{ .ct = c_type, .an = fmtId(arg.name) });
                        } else {
                            try writer.print("_{s}", .{arg.name});
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
                            try writer.print("{s}) }},", .{arg.name});
                        } else {
                            if (new_iface == null) {
                                try writer.writeAll(
                                    \\.{ .s = T.getInterface().name },
                                    \\.{ .u = version_to_construct },
                                );
                            }
                            try writer.writeAll(".{ .o = null },");
                        }
                    },
                }
            }
            try writer.writeAll("};\n");
        }
        const args = if (message.args.len > 0) "&_args" else "null";
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
                    try printAbsolute(side, writer, i);
                    try writer.print(", try _proxy.marshalConstructor({}, &_args, ", .{opcode});
                    try printAbsolute(side, writer, i);
                    try writer.writeAll(".getInterface()));");
                } else {
                    try writer.print(
                        \\return @ptrCast(*T, try _proxy.marshalConstructorVersioned({[opcode]}, &_args, T.getInterface(), version_to_construct));
                    , .{
                        .opcode = opcode,
                    });
                }
            },
        }
        try writer.writeAll("}\n");
    }
};

/// All data in this struct is immutable after creation in parse().
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

    fn parse(arena: mem.Allocator, parser: *xml.Parser) !Arg {
        var name: ?[]const u8 = null;
        var kind: ?std.meta.Tag(Type) = null;
        var interface: ?[]const u8 = null;
        var allow_null: ?bool = null;
        var enum_name: ?[]const u8 = null;

        while (parser.next()) |ev| switch (ev) {
            .attribute => |attr| {
                if (mem.eql(u8, attr.name, "name")) {
                    if (name != null) return error.DuplicateName;
                    name = try attr.dupeValue(arena);
                } else if (mem.eql(u8, attr.name, "type")) {
                    if (kind != null) return error.DuplicateType;
                    kind = std.meta.stringToEnum(std.meta.Tag(Type), try attr.dupeValue(arena)) orelse
                        return error.InvalidType;
                } else if (mem.eql(u8, attr.name, "interface")) {
                    if (interface != null) return error.DuplicateInterface;
                    interface = try attr.dupeValue(arena);
                } else if (mem.eql(u8, attr.name, "allow-null")) {
                    if (allow_null != null) return error.DuplicateAllowNull;
                    if (!attr.valueEql("true") and !attr.valueEql("false")) return error.InvalidBoolValue;
                    allow_null = attr.valueEql("true");
                } else if (mem.eql(u8, attr.name, "enum")) {
                    if (enum_name != null) return error.DuplicateEnum;
                    enum_name = try attr.dupeValue(arena);
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
                        const us_index = mem.indexOfScalar(u8, name, '_') orelse 0;
                        try writer.print("common.{s}.{s}{}", .{
                            name[0..us_index],
                            name[us_index + 1 .. dot_index + 1],
                            titleCase(name[dot_index + 1 ..]),
                        });
                    } else {
                        try writer.print("{}", .{titleCase(name)});
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

/// All data in this struct is immutable after creation in parse().
const Enum = struct {
    name: []const u8,
    since: u32,
    entries: []const Entry,
    bitfield: bool,

    fn parse(arena: mem.Allocator, parser: *xml.Parser) !Enum {
        var name: ?[]const u8 = null;
        var since: ?u32 = null;
        var entries = std.ArrayList(Entry).init(gpa);
        defer entries.deinit();
        var bitfield: ?bool = null;

        while (parser.next()) |ev| switch (ev) {
            .open_tag => |tag| {
                // TODO: parse description
                if (mem.eql(u8, tag, "entry"))
                    try entries.append(try Entry.parse(arena, parser));
            },
            .attribute => |attr| {
                if (mem.eql(u8, attr.name, "name")) {
                    if (name != null) return error.DuplicateName;
                    name = try attr.dupeValue(arena);
                } else if (mem.eql(u8, attr.name, "since")) {
                    if (since != null) return error.DuplicateSince;
                    since = try std.fmt.parseInt(u32, try attr.dupeValue(arena), 10);
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
                    .entries = try arena.dupe(Entry, entries.items),
                    .bitfield = bitfield orelse false,
                };
            },
            else => {},
        };
        return error.UnexpectedEndOfFile;
    }

    fn emit(e: Enum, target_version: u32, writer: anytype) !void {
        try writer.print("pub const {}", .{titleCase(e.name)});

        if (e.bitfield) {
            var entries_emitted: u8 = 0;
            try writer.writeAll(" = packed struct(u32) {");
            for (e.entries) |entry| {
                if (entry.since <= target_version) {
                    const value = entry.intValue();
                    if (value != 0 and std.math.isPowerOfTwo(value)) {
                        try writer.print("{s}: bool = false,", .{entry.name});
                        entries_emitted += 1;
                    }
                }
            }
            if (entries_emitted < 32) {
                try writer.print("_padding: u{d} = 0,\n", .{32 - entries_emitted});
            }

            // Emit the normal C abi enum as well as it may be needed to interface
            // with C code.
            try writer.writeAll("pub const Enum ");
        }

        try writer.writeAll(" = enum(c_int) {");
        for (e.entries) |entry| {
            if (entry.since <= target_version) {
                try writer.print("{s}= {s},", .{ fmtId(entry.name), entry.value });
            }
        }
        // Always generate non-exhaustive enums to ensure forward compatability.
        // Entries have been added to wl_shm.format without bumping the version.
        try writer.writeAll("_,};\n");

        if (e.bitfield) try writer.writeAll("};\n");
    }
};

/// All data in this struct is immutable after creation in parse().
const Entry = struct {
    name: []const u8,
    since: u32,
    value: []const u8,

    fn parse(arena: mem.Allocator, parser: *xml.Parser) !Entry {
        var name: ?[]const u8 = null;
        var since: ?u32 = null;
        var value: ?[]const u8 = null;

        while (parser.next()) |ev| switch (ev) {
            .attribute => |attr| {
                if (mem.eql(u8, attr.name, "name")) {
                    if (name != null) return error.DuplicateName;
                    name = try attr.dupeValue(arena);
                } else if (mem.eql(u8, attr.name, "since")) {
                    if (since != null) return error.DuplicateSince;
                    since = try std.fmt.parseInt(u32, try attr.dupeValue(arena), 10);
                } else if (mem.eql(u8, attr.name, "value")) {
                    if (value != null) return error.DuplicateName;
                    value = try attr.dupeValue(arena);
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

const Case = enum { title, camel };

fn formatCaseImpl(comptime case: Case, comptime trim: bool) type {
    return struct {
        pub fn f(
            bytes: []const u8,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            var upper = case == .title;
            var str = if (trim) trimPrefix(bytes) else bytes;
            for (str) |c| {
                if (c == '_') {
                    upper = true;
                    continue;
                }
                try writer.writeByte(if (upper) std.ascii.toUpper(c) else c);
                upper = false;
            }
        }
    };
}

fn titleCase(bytes: []const u8) std.fmt.Formatter(formatCaseImpl(.title, false).f) {
    return .{ .data = bytes };
}

fn titleCaseTrim(bytes: []const u8) std.fmt.Formatter(formatCaseImpl(.title, true).f) {
    return .{ .data = bytes };
}

fn camelCase(bytes: []const u8) std.fmt.Formatter(formatCaseImpl(.camel, false).f) {
    return .{ .data = bytes };
}

fn camelCaseTrim(bytes: []const u8) std.fmt.Formatter(formatCaseImpl(.camel, true).f) {
    return .{ .data = bytes };
}

fn printAbsolute(side: Side, writer: anytype, interface: []const u8) !void {
    try writer.print("{s}.{s}.{}", .{
        @tagName(side),
        prefix(interface) orelse return error.MissingPrefix,
        titleCaseTrim(interface),
    });
}

test "parsing" {
    const testing = std.testing;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const protocol = try Protocol.parseXML(arena.allocator(), @embedFile("test_data/wayland.xml"));

    try testing.expectEqualSlices(u8, "wayland", protocol.name);
    try testing.expectEqual(@as(usize, 7), protocol.globals.len);

    {
        const wl_display = protocol.version_locked_interfaces[0];
        try testing.expectEqualSlices(u8, "wl_display", wl_display.name);
        try testing.expectEqual(@as(u32, 1), wl_display.version);
        try testing.expectEqual(@as(usize, 2), wl_display.requests.len);
        try testing.expectEqual(@as(usize, 2), wl_display.events.len);
        try testing.expectEqual(@as(usize, 1), wl_display.enums.len);

        {
            const sync = wl_display.requests[0];
            try testing.expectEqualSlices(u8, "sync", sync.name);
            try testing.expectEqual(@as(u32, 1), sync.since);
            try testing.expectEqual(@as(usize, 1), sync.args.len);
            {
                const callback = sync.args[0];
                try testing.expectEqualSlices(u8, "callback", callback.name);
                try testing.expect(callback.kind == .new_id);
                try testing.expectEqualSlices(u8, "wl_callback", callback.kind.new_id.?);
                try testing.expectEqual(false, callback.allow_null);
                try testing.expectEqual(@as(?[]const u8, null), callback.enum_name);
            }
            try testing.expect(sync.kind == .constructor);
        }

        {
            const error_event = wl_display.events[0];
            try testing.expectEqualSlices(u8, "error", error_event.name);
            try testing.expectEqual(@as(u32, 1), error_event.since);
            try testing.expectEqual(@as(usize, 3), error_event.args.len);
            {
                const object_id = error_event.args[0];
                try testing.expectEqualSlices(u8, "object_id", object_id.name);
                try testing.expectEqual(Arg.Type{ .object = null }, object_id.kind);
                try testing.expectEqual(false, object_id.allow_null);
                try testing.expectEqual(@as(?[]const u8, null), object_id.enum_name);
            }
            {
                const code = error_event.args[1];
                try testing.expectEqualSlices(u8, "code", code.name);
                try testing.expectEqual(Arg.Type.uint, code.kind);
                try testing.expectEqual(false, code.allow_null);
                try testing.expectEqual(@as(?[]const u8, null), code.enum_name);
            }
            {
                const message = error_event.args[2];
                try testing.expectEqualSlices(u8, "message", message.name);
                try testing.expectEqual(Arg.Type.string, message.kind);
                try testing.expectEqual(false, message.allow_null);
                try testing.expectEqual(@as(?[]const u8, null), message.enum_name);
            }
        }

        {
            const error_enum = wl_display.enums[0];
            try testing.expectEqualSlices(u8, "error", error_enum.name);
            try testing.expectEqual(@as(u32, 1), error_enum.since);
            try testing.expectEqual(@as(usize, 4), error_enum.entries.len);
            {
                const invalid_object = error_enum.entries[0];
                try testing.expectEqualSlices(u8, "invalid_object", invalid_object.name);
                try testing.expectEqual(@as(u32, 1), invalid_object.since);
                try testing.expectEqualSlices(u8, "0", invalid_object.value);
            }
            {
                const invalid_method = error_enum.entries[1];
                try testing.expectEqualSlices(u8, "invalid_method", invalid_method.name);
                try testing.expectEqual(@as(u32, 1), invalid_method.since);
                try testing.expectEqualSlices(u8, "1", invalid_method.value);
            }
            {
                const no_memory = error_enum.entries[2];
                try testing.expectEqualSlices(u8, "no_memory", no_memory.name);
                try testing.expectEqual(@as(u32, 1), no_memory.since);
                try testing.expectEqualSlices(u8, "2", no_memory.value);
            }
            {
                const implementation = error_enum.entries[3];
                try testing.expectEqualSlices(u8, "implementation", implementation.name);
                try testing.expectEqual(@as(u32, 1), implementation.since);
                try testing.expectEqualSlices(u8, "3", implementation.value);
            }
            try testing.expectEqual(false, error_enum.bitfield);
        }
    }

    {
        const wl_data_offer = protocol.globals[2].children[2];
        try testing.expectEqualSlices(u8, "wl_data_offer", wl_data_offer.name);
        try testing.expectEqual(@as(u32, 3), wl_data_offer.version);
        try testing.expectEqual(@as(usize, 5), wl_data_offer.requests.len);
        try testing.expectEqual(@as(usize, 3), wl_data_offer.events.len);
        try testing.expectEqual(@as(usize, 1), wl_data_offer.enums.len);

        {
            const accept = wl_data_offer.requests[0];
            try testing.expectEqualSlices(u8, "accept", accept.name);
            try testing.expectEqual(@as(u32, 1), accept.since);
            try testing.expectEqual(@as(usize, 2), accept.args.len);
            {
                const serial = accept.args[0];
                try testing.expectEqualSlices(u8, "serial", serial.name);
                try testing.expectEqual(Arg.Type.uint, serial.kind);
                try testing.expectEqual(false, serial.allow_null);
            }
            {
                const mime_type = accept.args[1];
                try testing.expectEqualSlices(u8, "mime_type", mime_type.name);
                try testing.expectEqual(Arg.Type.string, mime_type.kind);
                try testing.expectEqual(true, mime_type.allow_null);
            }
        }
    }
}
