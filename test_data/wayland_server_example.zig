const wayland = @import("wayland.zig");
const server = wayland.server;
const common = wayland.common;

pub const Display = opaque {
    pub const interface = &wayland.common.wl.display;

    pub const Request = union(enum) {
        sync: struct {
            callback: u32
        },
        get_registry: struct {
            registry: u32,
        },
    };
};

pub const Registry = opaque {
    pub const interface = &wayland.common.wl.registry;

    pub const Request = union(enum) {
        bind: struct {
            name: u32,
            interface: [*:0]const u8,
            version: u32,
            id: u32,
        },
    };

    pub fn create(client: *server.Client, version: u32, id: u32) !*Registry {
        return @ptrCast(*Registry, try server.Resource.create(client, Registry, version, id));
    }

    pub fn setHandler(
        registry: *Registry,
        comptime T: type,
        handler: fn (registry: *Registry, request: Request, data: T) void,
        data: T,
        destroy: fn (registry: *Registry) callconv(.C) void,
    ) void {
        const resource = @ptrCast(*server.Resource, registry);
        resource.setDispatcher(
            common.Dispatcher(Registry, T).dispatcher,
            handler,
            data,
            @ptrCast(resource.DestroyFn, destroy),
        );
    }

    pub fn sendGlobal(registry: *Registry, name: u32, interface: [*:0]const u8, version: u32) void {
        const resource = @ptrCast(*server.Resource, registry);
        var args = [_]common.Argument{
            .{ .u = name },
            .{ .s = interface },
            .{ .u = version },
        };
        resource.postEvent(0, &args);
    }

    pub fn sendGlobalRemove(registry: *Registry, name: u32) void {
        const resource = @ptrCast(*server.Resource, registry);
        var args = [_]common.Argument{
            .{ .u = name },
            .{ .s = interface },
            .{ .u = version },
        };
        resource.postEvent(0, &args);
    }
};
