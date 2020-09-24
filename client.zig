const std = @import("std");
const os = std.os;

const common = @import("common.zig");
pub usingnamespace @import("test_data/client_proto.zig");

pub const Proxy = struct {
    pub const Impl = @OpaqueType();
    impl: *Impl,

    extern fn wl_proxy_create(factory: *Impl, interface: *const common.Interface) *Impl;
    pub fn create(factory: Proxy, interface: *const common.Interface) error{OutOfMemory}!Proxy {
        return .{ .impl = wl_proxy_create(factory.impl, interface) orelse return error.OutOfMemory };
    }

    extern fn wl_proxy_destroy(proxy: *Impl) void;
    pub fn destroy(proxy: Proxy) void {
        wl_proxy_destroy(proxy.impl);
    }

    extern fn wl_proxy_marshal_array(proxy: *Impl, opcode: u32, args: [*]common.Argument) void;
    pub fn marshal(proxy: Proxy, opcode: u32, args: [*]common.Argument) void {
        wl_proxy_marshal_array(proxy.impl, opcode, args);
    }

    extern fn wl_proxy_marshal_array_constructor(
        proxy: *Impl,
        opcode: u32,
        args: [*]common.Argument,
        interface: *const common.Interface,
    ) ?*Impl;
    pub fn marshalConstructor(
        proxy: Proxy,
        opcode: u32,
        args: [*]common.Argument,
        interface: *const common.Interface,
    ) error{OutOfMemory}!Proxy {
        return Proxy{
            .impl = wl_proxy_marshal_array_constructor(proxy.impl, opcode, args, interface) orelse
                return error.OutOfMemory,
        };
    }

    extern fn wl_proxy_marshal_array_constructor_versioned(
        proxy: *Impl,
        opcode: u32,
        args: [*]common.Argument,
        interface: *common.Interface,
        version: u32,
    ) ?*Impl;
    pub fn marshalConstructorVersioned(
        proxy: Proxy,
        opcode: u32,
        args: [*]common.Argument,
        interface: *const common.Interface,
        version: u32,
    ) error{OutOfMemory}!Proxy {
        return .{
            .impl = wl_proxy_marshal_array_constructor(proxy.impl, opcode, args, interface, version) orelse
                return error.OutOfMemory,
        };
    }

    extern fn wl_proxy_add_listener(proxy: *Proxy.Impl, implementation: [*]fn () callconv(.C) void, data: ?*c_void) i32;
    pub fn addListener(proxy: Proxy, implementation: [*]fn () callconv(.C) void, data: ?*c_void) error{AlreadyHasListener}!void {
        if (wl_proxy_add_listener(proxy.impl, implementation, data) == -1) return error.AlreadyHasListener;
    }

    extern fn wl_proxy_set_user_data(proxy: *Impl, user_data: ?*c_void) void;
    pub fn setUserData(proxy: Proxy, user_data: ?*c_void) void {
        wl_proxy_set_user_data(proxy.impl, user_data);
    }
    extern fn wl_proxy_get_user_data(proxy: *Impl) ?*c_void;
    pub fn getUserData(proxy: Proxy) ?*c_void {
        return wl_proxy_get_user_data(proxy.impl);
    }

    extern fn wl_proxy_get_version(proxy: *Impl) u32;
    pub fn getVersion(proxy: Proxy) u32 {
        return wl_proxy_get_version(proxy.impl);
    }

    extern fn wl_proxy_get_id(proxy: *Impl) u32;
    pub fn getId(proxy: Proxy) u32 {
        return wl_proxy_get_id(proxy.impl);
    }
};

pub const display_functions = struct {
    const Impl = Display.Impl;

    extern fn wl_display_connect(name: ?[*:0]const u8) ?*Impl;
    pub fn connect(name: ?[*:0]const u8) error{ConnectFailed}!Display {
        return Display{ .impl = wl_display_connect(name) orelse return error.ConnectFailed };
    }

    extern fn wl_display_connect_to_fd(fd: c_int) ?*Impl;
    pub fn connectToFd(fd: os.fd_t) error{ConnectFailed}!Display {
        return .{ .impl = wl_display_connect_to_fd(fd) orelse return error.ConnectFailed };
    }

    extern fn wl_display_disconnect(display: *Impl) void;
    pub fn disconnect(self: Display) void {
        wl_display_disconnect(self.impl);
    }

    extern fn wl_display_get_fd(display: *Impl) c_int;
    pub fn getFd(self: Display) os.fd_t {
        return wl_display_get_fd(self.impl);
    }

    extern fn wl_display_dispatch(display: *Impl) c_int;
    pub fn dispatch(self: Display) !void {
        const rc = wl_display_dispatch(self.impl);
        return switch (os.errno(rc)) {
            0 => @intCast(u31, rc),
            // TODO
            else => |err| os.unexpectedErrno(err),
        };
    }

    extern fn wl_display_dispatch_pending(display: *Impl) c_int;
    pub fn dispatchPending(self: Display) !u31 {
        const rc = wl_display_dispatch_pending(self.impl);
        return switch (os.errno(rc)) {
            0 => @intCast(u31, rc),
            // TODO
            else => |err| os.unexpectedErrno(err),
        };
    }

    extern fn wl_display_dispatch_queue(display: *Impl, queue: *EventQueue.Impl) c_int;
    pub fn dispatchQueue(self: Display, queue: EventQueue) !u31 {
        const rc = wl_display_dispatch_queue(self.impl, queue.impl);
        return switch (os.errno(rc)) {
            0 => @intCast(u31, rc),
            // TODO
            else => |err| os.unexpectedErrno(err),
        };
    }

    extern fn wl_display_dispatch_queue_pending(display: *Impl, queue: *EventQueue.Impl) c_int;
    pub fn dispatchQueuePending(self: Display, queue: EventQueue) !u31 {
        const rc = wl_display_dispatch_queue_pending(self.impl, queue.impl);
        return switch (os.errno(rc)) {
            0 => @intCast(u31, rc),
            // TODO
            else => |err| os.unexpectedErrno(err),
        };
    }

    extern fn wl_display_roundtrip(display: *Impl) c_int;
    pub fn roundtrip(self: Display) !u31 {
        const rc = wl_display_roundtrip(self.impl);
        return switch (os.errno(rc)) {
            0 => @intCast(u31, rc),
            // TODO
            else => |err| os.unexpectedErrno(err),
        };
    }

    extern fn wl_display_roundtrip_queue(display: *Impl, queue: *EventQueue.Impl) c_int;
    pub fn roundtripQueue(self: Display, queue: EventQueue) !u31 {
        const rc = wl_display_roundtrip_queue(self.impl, queue.impl);
        return switch (os.errno(rc)) {
            0 => @intCast(u31, rc),
            // TODO
            else => |err| os.unexpectedErrno(err),
        };
    }

    extern fn wl_display_flush(display: *Impl) c_int;
    pub fn flush(self: Display) error{WouldBlock}!u31 {
        const rc = wl_display_dispatch_queue_pending(self.impl, queue.impl);
        return switch (os.errno(rc)) {
            0 => @intCast(u31, rc),
            os.EAGAIN => error.WouldBlock,
            else => unreachable,
        };
    }

    extern fn wl_display_create_queue(display: *Impl) *EventQueue.Impl;
    pub fn createQueue(self: Display) error{OutOfMemory}!EventQueue {
        return .{ .impl = wl_display_create_queue(self.impl) orelse return error.OutOfMemory };
    }

    // TODO: should we interpret this return value?
    extern fn wl_display_get_error(display: *Impl) c_int;
    pub fn getError(self: Display) i32 {
        return wl_display_get_error(self.impl);
    }
};

pub const EventQueue = struct {
    const Impl = @OpaqueType();
    impl: *Impl,

    extern fn wl_event_queue_destroy(queue: *Impl) void;
    pub fn destroy(event_queue: EventQueue) void {
        wl_event_queue_destroy(event_queue.impl);
    }
};
