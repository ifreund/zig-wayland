const std = @import("std");
const os = std.os;

const wl_display = @OpaqueType();
pub const Display = struct {
    const Self = @This();

    impl: *wl_display,

    extern fn wl_display_connect(name: ?[*:0]const u8) *wl_display;
    pub fn connect(name: [*:0]const u8) error{ConnectFailed}!Display {
        return .{ .impl = wl_display_connect(name) orelse return error.ConnectFailed };
    }

    extern fn wl_display_connect_to_fd(fd: c_int) *wl_display;
    pub fn connectToFd(fd: os.fd_t) error{ConnectFailed}!Display {
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
    pub fn createQueue(self: Self) !EventQueue {
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
