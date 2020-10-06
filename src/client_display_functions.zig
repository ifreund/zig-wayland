const os = @import("std").os;

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

extern fn wl_display_dispatch_queue(display: *Display, queue: *client.EventQueue) c_int;
pub fn dispatchQueue(display: *Display, queue: *client.EventQueue) !u31 {
    const rc = wl_display_dispatch_queue(display, queue);
    return switch (os.errno(rc)) {
        0 => @intCast(u31, rc),
        // TODO
        else => |err| os.unexpectedErrno(err),
    };
}

extern fn wl_display_dispatch_queue_pending(display: *Display, queue: *client.EventQueue) c_int;
pub fn dispatchQueuePending(display: *Display, queue: *client.EventQueue) !u31 {
    const rc = wl_display_dispatch_queue_pending(display, queue);
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

extern fn wl_display_roundtrip_queue(display: *Display, queue: *client.EventQueue) c_int;
pub fn roundtripQueue(display: *Display, queue: *client.EventQueue) !u31 {
    const rc = wl_display_roundtrip_queue(display, queue);
    return switch (os.errno(rc)) {
        0 => @intCast(u31, rc),
        // TODO
        else => |err| os.unexpectedErrno(err),
    };
}

extern fn wl_display_flush(display: *Display) c_int;
pub fn flush(display: *Display) error{WouldBlock}!u31 {
    const rc = wl_display_dispatch_queue_pending(display, queue);
    return switch (os.errno(rc)) {
        0 => @intCast(u31, rc),
        os.EAGAIN => error.WouldBlock,
        else => unreachable,
    };
}

extern fn wl_display_create_queue(display: *Display) *client.EventQueue;
pub fn createQueue(display: *Display) error{OutOfMemory}!*client.EventQueue {
    return wl_display_create_queue(display) orelse error.OutOfMemory;
}

// TODO: should we interpret this return value?
extern fn wl_display_get_error(display: *Display) c_int;
pub fn getError(display: *Display) c_int {
    return wl_display_get_error(display);
}
