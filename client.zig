const std = @import("std");
const os = std.os;

const common = @import("common.zig");
pub usingnamespace @import("test_data/client_proto.zig");

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

pub const display_functions = struct {
    extern fn wl_display_connect(name: ?[*:0]const u8) ?*Display;
    pub fn connect(name: ?[*:0]const u8) error{ConnectFailed}!*Display {
        return wl_display_connect(name) orelse return error.ConnectFailed;
    }

    extern fn wl_display_connect_to_fd(fd: c_int) ?*Display;
    pub fn connectToFd(fd: os.fd_t) error{ConnectFailed}!*Display {
        return wl_display_connect_to_fd(fd) orelse return error.ConnectFailed;
    }

    extern fn wl_display_disconnect(display: *Display) void;
    pub fn disconnect(display: *Display) void {
        wl_display_disconnect(display);
    }

    extern fn wl_display_get_fd(display: *Display) c_int;
    pub fn getFd(display: *Display) os.fd_t {
        return wl_display_get_fd(display);
    }

    extern fn wl_display_dispatch(display: *Display) c_int;
    pub fn dispatch(display: *Display) !void {
        const rc = wl_display_dispatch(display);
        return switch (os.errno(rc)) {
            0 => @intCast(u31, rc),
            // TODO
            else => |err| os.unexpectedErrno(err),
        };
    }

    extern fn wl_display_dispatch_pending(display: *Display) c_int;
    pub fn dispatchPending(display: *Display) !u31 {
        const rc = wl_display_dispatch_pending(display);
        return switch (os.errno(rc)) {
            0 => @intCast(u31, rc),
            // TODO
            else => |err| os.unexpectedErrno(err),
        };
    }

    extern fn wl_display_dispatch_queue(display: *Display, queue: *EventQueue.Impl) c_int;
    pub fn dispatchQueue(display: *Display, queue: EventQueue) !u31 {
        const rc = wl_display_dispatch_queue(display, queue.impl);
        return switch (os.errno(rc)) {
            0 => @intCast(u31, rc),
            // TODO
            else => |err| os.unexpectedErrno(err),
        };
    }

    extern fn wl_display_dispatch_queue_pending(display: *Display, queue: *EventQueue.Impl) c_int;
    pub fn dispatchQueuePending(display: *Display, queue: EventQueue) !u31 {
        const rc = wl_display_dispatch_queue_pending(display, queue.impl);
        return switch (os.errno(rc)) {
            0 => @intCast(u31, rc),
            // TODO
            else => |err| os.unexpectedErrno(err),
        };
    }

    extern fn wl_display_roundtrip(display: *Display) c_int;
    pub fn roundtrip(display: *Display) !u31 {
        const rc = wl_display_roundtrip(display);
        return switch (os.errno(rc)) {
            0 => @intCast(u31, rc),
            // TODO
            else => |err| os.unexpectedErrno(err),
        };
    }

    extern fn wl_display_roundtrip_queue(display: *Display, queue: *EventQueue.Impl) c_int;
    pub fn roundtripQueue(display: *Display, queue: EventQueue) !u31 {
        const rc = wl_display_roundtrip_queue(display, queue.impl);
        return switch (os.errno(rc)) {
            0 => @intCast(u31, rc),
            // TODO
            else => |err| os.unexpectedErrno(err),
        };
    }

    extern fn wl_display_flush(display: *Display) c_int;
    pub fn flush(display: *Display) error{WouldBlock}!u31 {
        const rc = wl_display_dispatch_queue_pending(display, queue.impl);
        return switch (os.errno(rc)) {
            0 => @intCast(u31, rc),
            os.EAGAIN => error.WouldBlock,
            else => unreachable,
        };
    }

    extern fn wl_display_create_queue(display: *Display) *EventQueue.Impl;
    pub fn createQueue(display: *Display) error{OutOfMemory}!EventQueue {
        return .{ .impl = wl_display_create_queue(display) orelse return error.OutOfMemory };
    }

    // TODO: should we interpret this return value?
    extern fn wl_display_get_error(display: *Display) c_int;
    pub fn getError(display: *Display) i32 {
        return wl_display_get_error(display);
    }
};

pub const EventQueue = opaque {
    extern fn wl_event_queue_destroy(queue: *EventQueue) void;
    pub fn destroy(event_queue: *EventQueue) void {
        wl_event_queue_destroy(event_queue);
    }
};
