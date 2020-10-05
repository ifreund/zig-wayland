const wayland = @import("wayland.zig");
const common = wayland.common;

pub const Client = opaque {};

pub const Global = opaque {
    extern fn wl_global_create(
        display: *wl.Display,
        interface: *const common.Interface,
        version: c_int,
        data: ?*c_void,
        bind: fn (client: *Client, data: ?*c_void, version: u32, id: u32) callconv(.C) void,
    ) ?*Global;
    pub fn create(
        display: *wl.Display,
        comptime ObjectT: type,
        version: u32,
        comptime T: type,
        data: T,
        bind: fn (client: *Client, data: T, version: u32, id: u32) callconv(.C) void,
    ) !*Global {
        return wl_global_create(display, ObjectT.interface, version, data, bind) orelse
            error.GlobalCreateFailed;
    }

    extern fn wl_global_remove(global: *Global) void;
    pub fn remove(global: *Global) void {
        wl_global_remove(global);
    }

    extern fn wl_global_destroy(global: *Global) void;
    pub fn destroy(global: *Global) void {
        wl_global_destroy(global);
    }
};

pub const Resource = opaque {
    extern fn wl_resource_post_event_array(resource: *Resource, opcode: u32, args: [*]common.Argument) void;
    pub fn postEvent(resource: *Resource, opcode: u32, args: [*]common.Argument) void {
        wl_resource_post_event_array(resource, opcode, args);
    }

    extern fn wl_resource_queue_event_array(resource: *Resource, opcode: u32, args: [*]common.Argument) void;
    pub fn queueEvent(resource: *Resource, opcode: u32, args: [*]common.Argument) void {
        wl_resource_queue_event_array(resource, opcode, args);
    }

    extern fn wl_resource_post_error(resource: *Resource, code: u32, message: [*:0]const u8, ...) void;
    pub fn postError(resource: *Resource, code: u32, message: [*:0]const u8) void {
        wl_resource_post_error(resource, code, message);
    }

    extern fn wl_resource_post_no_memory(resource: *Resource) void;
    pub fn postNoMemory(resource: *Resource) void {
        wl_resource_post_no_memory(resource);
    }

    const DispatcherFn = fn (
        implementation: ?*const c_void,
        resource: *Resource,
        opcode: u32,
        message: *const common.Message,
        args: [*]common.Argument,
    ) callconv(.C) c_int;
    const DestroyFn = fn (resource: *Resource) callconv(.C) void;
    extern fn wl_resource_set_dispatcher(
        resource: *Resource,
        dispatcher: DispatcherFn,
        implementation: ?*const c_void,
        data: ?*c_void,
        destroy: DestroyFn,
    ) void;
    pub fn setDispatcher(
        resource: *Resource,
        dispatcher: DispatcherFn,
        implementation: ?*const c_void,
        data: ?*c_void,
        destroy: DestroyFn,
    ) !void {
        if (wl_resource_set_dispatcher(proxy, dispatcher, implementation, data) == -1)
            return error.AlreadyHasListener;
    }

    extern fn wl_resource_destroy(resource: *Resource) void;
    pub fn destroy(resource: *Resource) void {
        wl_resource_destroy(resource);
    }

    extern fn wl_resource_get_user_data(resource: *Resource) ?*c_void;
    pub fn getUserData(resource: *Resource) ?*c_void {
        return wl_resource_get_user_data(resource);
    }
};

pub const ProtocolLogger = opaque {
    pub const Type = extern enum {
        request,
        event,
    };

    pub const Message = extern struct {
        resource: *Resource,
        message_opcode: c_int,
        message: *common.Message,
        arguments_count: c_int,
        arguments: ?[*]common.Argument,
    };

    extern fn wl_protocol_logger_destroy(logger: *ProtocolLogger) void;
    pub fn destroy(logger: *ProtocolLogger) void {
        wl_protocol_logger_destroy(logger);
    }
};
