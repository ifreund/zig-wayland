const common = @import("../common.zig");
const client = @import("../client.zig");

pub const Display = opaque {
    pub usingnamespace client.display_functions;

    pub const interface = common.Interface{
        .name = "wl_display",
        .version = 1,
        .method_count = 2,
        .methods = &[_]common.Message{
            .{
                .name = "sync",
                .signature = "n",
                .types = &[_]?*common.Interface{&Callback.interface},
            },
            .{
                .name = "get_registry",
                .signature = "n",
                .types = &[_]?*common.Interface{&Registry.interface},
            },
        },
        .event_count = 2,
        .events = &[_]common.Message{
            .{
                .name = "error",
                .signature = "ous",
                .types = &[_]?*common.Interface{ null, null, null },
            },
            .{
                .name = "delete_id",
                .signature = "u",
                .types = &[_]?*common.Interface{null},
            },
        },
    };

    pub const opcodes = struct {
        pub const sync = 0;
        pub const get_registry = 1;
    };

    pub const since_versions = struct {
        pub const @"error" = 1;
        pub const delete_id = 1;
        pub const sync = 1;
        pub const get_registry = 1;
    };

    pub const Error = enum {
        invalid_object = 0,
        invalid_method = 1,
        no_memory = 2,
        implementation = 3,
    };

    pub fn Listener(comptime T: type) type {
        return extern struct {
            @"error": fn (
                data: T,
                display: *Display,
                object_id: ?*common.Object,
                code: u32,
                message: [*:0]const u8,
            ) callconv(.C) void,
            delete_id: fn (
                data: T,
                display: *Display,
                id: u32,
            ) callconv(.C) void,
        };
    }

    pub fn addListener(display: *Display, comptime T: type, listener: Listener(T), data: T) !void {
        const proxy = @ptrCast(*client.Proxy, display);
        try proxy.addListener(@intToPtr([*]fn () callconv(.C) void, @ptrToInt(&listener)), data);
    }

    pub fn sync(display: *Display) !*Callback {
        const proxy = @ptrCast(*client.Proxy, display);
        var args = [_]common.Argument{.{ .o = null }};
        return @ptrCast(*Callback, try proxy.marshalConstructor(opcodes.sync, &args, &Callback.interface));
    }

    pub fn getRegistry(display: *Display) !*Registry {
        const proxy = @ptrCast(*client.Proxy, display);
        var args = [_]common.Argument{.{ .o = null }};
        return @ptrCast(*Registry, try proxy.marshalConstructor(opcodes.get_registry, &args, &Registry.interface));
    }
};

pub const Registry = opaque {
    pub const interface = common.Interface{
        .name = "wl_registry",
        .version = 1,
        .method_count = 1,
        .methods = &[_]common.Message{.{
            .name = "bind",
            .signature = "usun",
            .types = &[_]?*common.Interface{ null, null, null, null },
        }},
        .event_count = 2,
        .events = &[_]common.Message{ .{
            .name = "global",
            .signature = "usu",
            .types = &[_]?*common.Interface{ null, null, null },
        }, .{
            .name = "global_remove",
            .signature = "u",
            .types = &[_]?*common.Interface{null},
        } },
    };

    pub const opcodes = struct {
        pub const bind = 0;
    };

    pub const since_versions = struct {
        pub const global = 1;
        pub const global_remove = 1;
        pub const bind = 1;
    };

    pub fn Listener(comptime T: type) type {
        return extern struct {
            global: fn (
                data: T,
                registry: *Registry,
                name: u32,
                interface: [*:0]const u8,
                version: u32,
            ) callconv(.C) void,
            global_remove: fn (
                data: T,
                registry: *Registry,
                name: u32,
            ) callconv(.C) void,
        };
    }

    pub fn addListener(registry: *Registry, comptime T: type, listener: Listener(T), data: T) !void {
        const proxy = @ptrCast(*client.Proxy, registry);
        try proxy.addListener(@intToPtr([*]fn () callconv(.C) void, @ptrToInt(&listener)), data);
    }

    pub fn bind(registry: *Registry, name: u32, comptime T: type, version: u32) !*T {
        const proxy = @ptrCast(*client.Proxy, registry);
        var args = [_]common.Argument{
            .{ .u = name },
            .{ .s = T.interface.name },
            .{ .u = version },
            .{ .o = null },
        };
        return @ptrCast(*T, proxy.marshalConstructorVersioned(opcodes.bind, &args, T.interface, version));
    }
};

pub const Callback = opaque {
    pub const interface = common.Interface{
        .name = "wl_callback",
        .version = 1,
        .method_count = 0,
        .methods = null,
        .event_count = 1,
        .events = &[_]common.Message{.{
            .name = "done",
            .signature = "u",
            .types = &[_]?*common.Interface{null},
        }},
    };

    pub const since_versions = struct {
        pub const done = 1;
    };

    pub fn Listener(comptime T: type) type {
        return extern struct {
            done: fn (
                data: T,
                callback: *Callback,
                callback_data: u32,
            ) callconv(.C) void,
        };
    }

    pub fn addListener(callback: *Callback, comptime T: type, listener: Listener(T), data: T) !void {
        const proxy = @ptrCast(*client.Proxy, callback);
        try proxy.addListener(@intToPtr([*]fn () callconv(.C) void, @ptrToInt(&listener)), data);
    }
};
