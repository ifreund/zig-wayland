extern fn wl_display_connect(name: ?[*:0]const u8) ?*Display;
pub fn connect(name: ?[*:0]const u8) error{ConnectFailed}!*Display {
    return wl_display_connect(name) orelse return error.ConnectFailed;
}

extern fn wl_display_connect_to_fd(fd: c_int) ?*Display;
pub fn connectToFd(fd: c_int) error{ConnectFailed}!*Display {
    return wl_display_connect_to_fd(fd) orelse return error.ConnectFailed;
}

extern fn wl_display_disconnect(display: *Display) void;
pub const disconnect = wl_display_disconnect;

extern fn wl_display_get_fd(display: *Display) c_int;
pub const getFd = wl_display_get_fd;

extern fn wl_display_dispatch(display: *Display) c_int;
pub fn dispatch(display: *Display) !u32 {
    const rc = wl_display_dispatch(display);
    // poll(2), sendmsg(2), recvmsg(2), EOVERFLOW, E2BIG
    return switch (os.errno(rc)) {
        os.linux.E.SUCCESS => @intCast(u32, rc),
        os.linux.E.FAULT => unreachable,
        os.linux.E.INTR => unreachable,
        os.linux.E.INVAL => unreachable,
        os.linux.E.NOMEM => error.SystemResources,
        os.linux.E.ACCES => error.AccessDenied,
        os.linux.E.AGAIN => unreachable,
        os.linux.E.ALREADY => error.FastOpenAlreadyInProgress,
        os.linux.E.BADF => unreachable,
        os.linux.E.CONNRESET => error.ConnectionResetByPeer,
        os.linux.E.DESTADDRREQ => unreachable,
        os.linux.E.ISCONN => unreachable,
        os.linux.E.MSGSIZE => error.MessageTooBig,
        os.linux.E.NOBUFS => error.SystemResources,
        os.linux.E.NOTCONN => unreachable,
        os.linux.E.NOTSOCK => unreachable,
        os.linux.E.OPNOTSUPP => unreachable,
        os.linux.E.PIPE => error.BrokenPipe,
        os.linux.E.CONNREFUSED => error.ConnectionRefused,
        os.linux.E.OVERFLOW => error.BufferOverflow,
        os.linux.E.@"2BIG" => error.BufferOverflow,
        else => |err| os.unexpectedErrno(err),
    };
}

extern fn wl_display_dispatch_queue(display: *Display, queue: *client.wl.EventQueue) c_int;
pub fn dispatchQueue(display: *Display, queue: *client.wl.EventQueue) !u32 {
    const rc = wl_display_dispatch_queue(display, queue);
    return switch (os.errno(rc)) {
        os.linux.E.SUCCESS => @intCast(u32, rc),
        os.linux.E.FAULT => unreachable,
        os.linux.E.INTR => unreachable,
        os.linux.E.INVAL => unreachable,
        os.linux.E.NOMEM => error.SystemResources,
        os.linux.E.ACCES => error.AccessDenied,
        os.linux.E.AGAIN => unreachable,
        os.linux.E.ALREADY => error.FastOpenAlreadyInProgress,
        os.linux.E.BADF => unreachable,
        os.linux.E.CONNRESET => error.ConnectionResetByPeer,
        os.linux.E.DESTADDRREQ => unreachable,
        os.linux.E.ISCONN => unreachable,
        os.linux.E.MSGSIZE => error.MessageTooBig,
        os.linux.E.NOBUFS => error.SystemResources,
        os.linux.E.NOTCONN => unreachable,
        os.linux.E.NOTSOCK => unreachable,
        os.linux.E.OPNOTSUPP => unreachable,
        os.linux.E.PIPE => error.BrokenPipe,
        os.linux.E.CONNREFUSED => error.ConnectionRefused,
        os.linux.E.OVERFLOW => error.BufferOverflow,
        os.linux.E.@"2BIG" => error.BufferOverflow,
        else => |err| os.unexpectedErrno(err),
    };
}

extern fn wl_display_dispatch_pending(display: *Display) c_int;
pub fn dispatchPending(display: *Display) !u32 {
    const rc = wl_display_dispatch_pending(display);
    return switch (os.errno(rc)) {
        os.linux.E.SUCCESS => @intCast(u32, rc),
        // TODO
        else => |err| os.unexpectedErrno(err),
    };
}

extern fn wl_display_dispatch_queue_pending(display: *Display, queue: *client.wl.EventQueue) c_int;
pub fn dispatchQueuePending(display: *Display, queue: *client.wl.EventQueue) !u32 {
    const rc = wl_display_dispatch_queue_pending(display, queue);
    return switch (os.errno(rc)) {
        os.linux.E.SUCCESS => @intCast(u32, rc),
        // TODO
        else => |err| os.unexpectedErrno(err),
    };
}

extern fn wl_display_roundtrip(display: *Display) c_int;
pub fn roundtrip(display: *Display) !u32 {
    const rc = wl_display_roundtrip(display);
    return switch (os.errno(rc)) {
        os.linux.E.SUCCESS => @intCast(u32, rc),
        // TODO
        else => |err| os.unexpectedErrno(err),
    };
}

extern fn wl_display_roundtrip_queue(display: *Display, queue: *client.wl.EventQueue) c_int;
pub fn roundtripQueue(display: *Display, queue: *client.wl.EventQueue) !u32 {
    const rc = wl_display_roundtrip_queue(display, queue);
    return switch (os.errno(rc)) {
        os.linux.E.SUCCESS => @intCast(u32, rc),
        // TODO
        else => |err| os.unexpectedErrno(err),
    };
}

extern fn wl_display_flush(display: *Display) c_int;
pub fn flush(display: *Display) error{WouldBlock}!u32 {
    const rc = wl_display_flush(display);
    return switch (os.errno(rc)) {
        os.linux.E.SUCCESS => @intCast(u32, rc),
        os.EAGAIN => error.WouldBlock,
        else => unreachable,
    };
}

extern fn wl_display_create_queue(display: *Display) ?*client.wl.EventQueue;
pub fn createQueue(display: *Display) error{OutOfMemory}!*client.wl.EventQueue {
    return wl_display_create_queue(display) orelse error.OutOfMemory;
}

// TODO: should we interpret this return value?
extern fn wl_display_get_error(display: *Display) c_int;
pub const getError = wl_display_get_error;
