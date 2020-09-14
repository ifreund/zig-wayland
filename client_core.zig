const std = @import("std");
const os = std.os;

pub usingnamespace @import("util.zig");

const wl_proxy = @OpaqueType();
pub const Proxy = struct {
    const Self = @This();

    impl: *wl_proxy,

    extern fn wl_proxy_create(factory: *wl_proxy, interface: *const Interface) *wl_proxy;
    pub fn create(factory: Proxy, interface: *const Interface) error{OutOfMemory}!Self {
        return .{ .impl = wl_proxy_create(factory.impl, interface) orelse return error.OutOfMemory };
    }

    extern fn wl_proxy_destroy(proxy: *wl_proxy) void;
    pub fn destroy(self: Self) void {
        wl_proxy_destroy(self.impl);
    }

    extern fn wl_proxy_marshal_array(proxy: *wl_proxy, opcode: u32, args: [*]Argument) void;
    pub fn marshal(self: Self, opcode: u32, args: [*]Argument) void {
        wl_proxy_marshal_array(self.impl, opcode, args);
    }

    extern fn wl_proxy_marshal_array_constructor(
        proxy: *wl_proxy,
        opcode: u32,
        args: [*]Argument,
        interface: *Interface,
    ) void;
    pub fn marshalConstructor(
        self: Self,
        opcode: u32,
        args: [*]Argument,
        interface: *const Interface,
    ) error{OutOfMemory}!Proxy {
        return .{
            .impl = wl_proxy_marshal_array_constructor(self.impl, opcode, args, interface) orelse
                return error.OutOfMemory,
        };
    }

    extern fn wl_proxy_marshal_array_constructor_versioned(
        proxy: *wl_proxy,
        opcode: u32,
        args: [*]Argument,
        interface: *Interface,
        version: u32,
    ) void;
    pub fn marshalConstructorVersioned(
        self: Self,
        opcode: u32,
        args: [*]Argument,
        interface: *const Interface,
        version: u32,
    ) error{OutOfMemory}!Proxy {
        return .{
            .impl = wl_proxy_marshal_array_constructor(self.impl, opcode, args, interface, version) orelse
                return error.OutOfMemory,
        };
    }

    extern fn wl_proxy_add_listener(proxy: *wl_proxy, implementation: [*]fn () void, data: ?*c_void) i32;
    pub fn addListener(self: Self, implementation: [*]fn () void, data: *c_void) error{AlreadyHasListener}!void {
        if (wl_proxy_add_listener(self.impl, implementation, data) == -1) return error.AlreadyHasListener;
    }

    extern fn wl_proxy_set_user_data(proxy: *wl_proxy, user_data: ?*c_void) void;
    pub fn setUserData(self: Self, user_data: ?*c_void) void {
        wl_proxy_set_user_data(self.impl, user_data);
    }

    extern fn wl_proxy_get_user_data(proxy: *wl_proxy) ?*c_void;
    pub fn getUserData(self: Self) ?*c_void {
        return wl_proxy_get_user_data(self.impl);
    }

    extern fn wl_proxy_get_version(proxy: *wl_proxy) u32;
    pub fn getVersion(self: Self) u32 {
        return wl_proxy_get_version(self.impl);
    }

    extern fn wl_proxy_get_id(proxy: *wl_proxy) u32;
    pub fn getId(self: Self) u32 {
        return wl_proxy_get_id(self.impl);
    }
};

const wl_display = @OpaqueType();
pub const Display = struct {
    const Self = @This();

    impl: *wl_display,

    extern fn wl_display_connect(name: ?[*:0]const u8) *wl_display;
    pub fn connect(name: [*:0]const u8) error{ConnectFailed}!Self {
        return .{ .impl = wl_display_connect(name) orelse return error.ConnectFailed };
    }

    extern fn wl_display_connect_to_fd(fd: c_int) *wl_display;
    pub fn connectToFd(fd: os.fd_t) error{ConnectFailed}!Self {
        return .{ .impl = wl_display_connect_to_fd(fd) orelse return error.ConnectFailed };
    }

    extern fn wl_display_disconnect(display: *wl_display) void;
    pub fn disconnect(self: Self) void {
        wl_display_disconnect(self.impl);
    }

    extern fn wl_display_get_fd(display: *wl_display) c_int;
    pub fn getFd(self: Self) os.fd_t {
        return wl_display_get_fd(self.impl);
    }

    extern fn wl_display_dispatch(display: *wl_display) c_int;
    pub fn dispatch(self: Self) !void {
        const rc = wl_display_dispatch(self.impl);
        return switch (os.errno(rc)) {
            0 => @intCast(u31, rc),
            // TODO
            else => |err| std.os.unexpectedErrno(err),
        };
    }

    extern fn wl_display_dispatch_pending(display: *wl_display) c_int;
    pub fn dispatchPending(self: Self) !u31 {
        const rc = wl_display_dispatch_pending(self.impl);
        return switch (os.errno(rc)) {
            0 => @intCast(u31, rc),
            // TODO
            else => |err| std.os.unexpectedErrno(err),
        };
    }

    extern fn wl_display_dispatch_queue(display: *wl_display, queue: *wl_event_queue) c_int;
    pub fn dispatchQueue(self: Self, queue: EventQueue) !u31 {
        const rc = wl_display_dispatch_queue(self.impl, queue.impl);
        return switch (os.errno(rc)) {
            0 => @intCast(u31, rc),
            // TODO
            else => |err| std.os.unexpectedErrno(err),
        };
    }

    extern fn wl_display_dispatch_queue_pending(display: *wl_display, queue: *wl_event_queue) c_int;
    pub fn dispatchQueuePending(self: Self, queue: EventQueue) !u31 {
        const rc = wl_display_dispatch_queue_pending(self.impl, queue.impl);
        return switch (os.errno(rc)) {
            0 => @intCast(u31, rc),
            // TODO
            else => |err| std.os.unexpectedErrno(err),
        };
    }

    extern fn wl_display_roundtrip(display: *wl_display) c_int;
    pub fn roundtrip(self: Self) !u31 {
        const rc = wl_display_roundtrip(self.impl);
        return switch (os.errno(rc)) {
            0 => @intCast(u31, rc),
            // TODO
            else => |err| std.os.unexpectedErrno(err),
        };
    }

    extern fn wl_display_roundtrip_queue(display: *wl_display, queue: *wl_event_queue) c_int;
    pub fn roundtrip(self: Self, queue: EventQueue) !u31 {
        const rc = wl_display_roundtrip(self.impl, queue.impl);
        return switch (os.errno(rc)) {
            0 => @intCast(u31, rc),
            // TODO
            else => |err| std.os.unexpectedErrno(err),
        };
    }

    extern fn wl_display_flush(display: *wl_display) c_int;
    pub fn flush(self: Self) error{WouldBlock}!u31 {
        const rc = wl_display_dispatch_queue_pending(self.impl, queue.impl);
        return switch (std.os.errno(rc)) {
            0 => @intCast(u31, rc),
            os.EAGAIN => error.WouldBlock,
            else => unreachable,
        };
    }

    extern fn wl_display_create_queue(display: *wl_display) *wl_event_queue;
    pub fn createQueue(self: Self) error{OutOfMemory}!EventQueue {
        return .{ .impl = wl_display_create_queue(self.impl) orelse return error.OutOfMemory };
    }

    // TODO: should we interpret this return value?
    extern fn wl_display_get_error(display: *wl_display) c_int;
    pub fn getError(self: Self) i32 {
        return wl_display_get_error(self.impl);
    }
};

const wl_event_queue = @OpaqueType();
pub const EventQueue = struct {
    const Self = @This();

    impl: *wl_event_queue,

    extern fn wl_event_queue_destroy(queue: *wl_event_queue) void;
    pub fn destroy(self: Self) void {
        wl_event_queue_destroy(self.impl);
    }
};
