const common = @import("common.zig");
pub const Object = common.Object;
pub const Message = common.Message;
pub const Interface = common.Interface;
pub const Array = common.Array;
pub const Fixed = common.Fixed;
pub const Argument = common.Argument;

pub const Proxy = opaque {
    extern fn wl_proxy_create(factory: *Proxy, interface: *const Interface) *Proxy;
    pub fn create(factory: *Proxy, interface: *const Interface) error{OutOfMemory}!*Proxy {
        return wl_proxy_create(factory.impl, interface) orelse error.OutOfMemory;
    }

    extern fn wl_proxy_destroy(proxy: *Proxy) void;
    pub fn destroy(proxy: *Proxy) void {
        wl_proxy_destroy(proxy);
    }

    extern fn wl_proxy_marshal_array(proxy: *Proxy, opcode: u32, args: ?[*]Argument) void;
    pub const marshal = wl_proxy_marshal_array;

    extern fn wl_proxy_marshal_array_constructor(
        proxy: *Proxy,
        opcode: u32,
        args: [*]Argument,
        interface: *const Interface,
    ) ?*Proxy;
    pub fn marshalConstructor(
        proxy: *Proxy,
        opcode: u32,
        args: [*]Argument,
        interface: *const Interface,
    ) error{OutOfMemory}!*Proxy {
        return wl_proxy_marshal_array_constructor(proxy, opcode, args, interface) orelse
            error.OutOfMemory;
    }

    extern fn wl_proxy_marshal_array_constructor_versioned(
        proxy: *Proxy,
        opcode: u32,
        args: [*]Argument,
        interface: *const Interface,
        version: u32,
    ) ?*Proxy;
    pub fn marshalConstructorVersioned(
        proxy: *Proxy,
        opcode: u32,
        args: [*]Argument,
        interface: *const Interface,
        version: u32,
    ) error{OutOfMemory}!*Proxy {
        return wl_proxy_marshal_array_constructor_versioned(proxy, opcode, args, interface, version) orelse
            error.OutOfMemory;
    }

    const DispatcherFn = fn (
        implementation: ?*const c_void,
        proxy: *Proxy,
        opcode: u32,
        message: *const Message,
        args: [*]Argument,
    ) callconv(.C) c_int;
    extern fn wl_proxy_add_dispatcher(
        proxy: *Proxy,
        dispatcher: DispatcherFn,
        implementation: ?*const c_void,
        data: ?*c_void,
    ) c_int;
    pub fn addDispatcher(
        proxy: *Proxy,
        dispatcher: DispatcherFn,
        implementation: ?*const c_void,
        data: ?*c_void,
    ) !void {
        if (wl_proxy_add_dispatcher(proxy, dispatcher, implementation, data) == -1)
            return error.AlreadyHasListener;
    }

    // TODO: consider removing this to make setListener() on protocol objects
    // actually type safe for data
    extern fn wl_proxy_set_user_data(proxy: *Proxy, user_data: ?*c_void) void;
    pub fn setUserData(proxy: *Proxy, user_data: ?*c_void) void {
        wl_proxy_set_user_data(proxy, user_data);
    }
    extern fn wl_proxy_get_user_data(proxy: *Proxy) ?*c_void;
    pub fn getUserData(proxy: *Proxy) ?*c_void {
        return wl_proxy_get_user_data(proxy);
    }

    extern fn wl_proxy_get_version(proxy: *Proxy) u32;
    pub fn getVersion(proxy: *Proxy) u32 {
        return wl_proxy_get_version(proxy);
    }

    extern fn wl_proxy_get_id(proxy: *Proxy) u32;
    pub fn getId(proxy: *Proxy) u32 {
        return wl_proxy_get_id(proxy);
    }
};

pub const EventQueue = opaque {
    extern fn wl_event_queue_destroy(queue: *EventQueue) void;
    pub fn destroy(event_queue: *EventQueue) void {
        wl_event_queue_destroy(event_queue);
    }
};
