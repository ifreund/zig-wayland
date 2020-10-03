const wayland = @import("wayland.zig");
const common = wayland.common;

pub const Proxy = opaque {
    extern fn wl_proxy_create(factory: *Proxy, interface: *const common.Interface) *Proxy;
    pub fn create(factory: *Proxy, interface: *const common.Interface) error{OutOfMemory}!*Proxy {
        return wl_proxy_create(factory.impl, interface) orelse error.OutOfMemory;
    }

    extern fn wl_proxy_destroy(proxy: *Proxy) void;
    pub fn destroy(proxy: *Proxy) void {
        wl_proxy_destroy(proxy);
    }

    extern fn wl_proxy_marshal_array(proxy: *Proxy, opcode: u32, args: [*]common.Argument) void;
    pub fn marshal(proxy: *Proxy, opcode: u32, args: [*]common.Argument) void {
        wl_proxy_marshal_array(proxy, opcode, args);
    }

    extern fn wl_proxy_marshal_array_constructor(
        proxy: *Proxy,
        opcode: u32,
        args: [*]common.Argument,
        interface: *const common.Interface,
    ) ?*Proxy;
    pub fn marshalConstructor(
        proxy: *Proxy,
        opcode: u32,
        args: [*]common.Argument,
        interface: *const common.Interface,
    ) error{OutOfMemory}!*Proxy {
        return wl_proxy_marshal_array_constructor(proxy, opcode, args, interface) orelse
            error.OutOfMemory;
    }

    extern fn wl_proxy_marshal_array_constructor_versioned(
        proxy: *Proxy,
        opcode: u32,
        args: [*]common.Argument,
        interface: *common.Interface,
        version: u32,
    ) ?*Proxy;
    pub fn marshalConstructorVersioned(
        proxy: *Proxy,
        opcode: u32,
        args: [*]common.Argument,
        interface: *const common.Interface,
        version: u32,
    ) error{OutOfMemory}!*Proxy {
        return wl_proxy_marshal_array_constructor(proxy, opcode, args, interface, version) orelse
            error.OutOfMemory;
    }

    extern fn wl_proxy_add_listener(proxy: *Proxy, implementation: [*]fn () callconv(.C) void, data: ?*c_void) i32;
    pub fn addListener(proxy: *Proxy, implementation: [*]fn () callconv(.C) void, data: ?*c_void) error{AlreadyHasListener}!void {
        if (wl_proxy_add_listener(proxy, implementation, data) == -1) return error.AlreadyHasListener;
    }

    const DispatcherFn = fn (
        implementation: ?*const c_void,
        proxy: *Proxy,
        opcode: u32,
        message: *const common.Message,
        args: [*]common.Argument,
    ) callconv(.C) i32;
    extern fn wl_proxy_add_dispatcher(
        proxy: *Proxy,
        dispatcher: DispatcherFn,
        implementation: ?*const c_void,
        data: ?*c_void,
    ) i32;
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

pub fn Dispatcher(comptime ObjectT: type, comptime DataT: type) type {
    return struct {
        pub fn dispatcher(
            implementation: ?*const c_void,
            proxy: *Proxy,
            opcode: u32,
            message: *const common.Message,
            args: [*]common.Argument,
        ) callconv(.C) i32 {
            inline for (@typeInfo(ObjectT.Event).Union.fields) |event_field, event_num| {
                if (event_num == opcode) {
                    var event_data: event_field.field_type = undefined;
                    inline for (@typeInfo(event_field.field_type).Struct.fields) |f, i| {
                        @field(event_data, f.name) = switch (@sizeOf(f.field_type)) {
                            4 => @bitCast(f.field_type, args[i].u),
                            8 => @ptrCast(f.field_type, args[i].s),
                            else => unreachable,
                        };
                    }

                    const listener = @ptrCast(fn (object: *ObjectT, event: ObjectT.Event, data: DataT) void, implementation);
                    listener(
                        @ptrCast(*ObjectT, proxy),
                        @unionInit(ObjectT.Event, event_field.name, event_data),
                        @intToPtr(DataT, @ptrToInt(proxy.getUserData())),
                    );

                    return 0;
                }
            }
            unreachable;
        }
    };
}
