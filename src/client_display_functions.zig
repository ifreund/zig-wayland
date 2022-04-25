extern fn wl_display_connect(name: ?[*:0]const u8) ?*Display;
pub inline fn connect(name: ?[*:0]const u8) error{ConnectFailed}!*Display {
    return wl_display_connect(name) orelse return error.ConnectFailed;
}

extern fn wl_display_connect_to_fd(fd: c_int) ?*Display;
pub inline fn connectToFd(fd: c_int) error{ConnectFailed}!*Display {
    return wl_display_connect_to_fd(fd) orelse return error.ConnectFailed;
}

extern fn wl_display_disconnect(display: *Display) void;
pub const disconnect = wl_display_disconnect;

extern fn wl_display_get_fd(display: *Display) c_int;
pub const getFd = wl_display_get_fd;

extern fn wl_display_dispatch(display: *Display) c_int;
pub inline fn dispatch(display: *Display) os.E {
    return os.errno(wl_display_dispatch(display));
}

extern fn wl_display_dispatch_queue(display: *Display, queue: *client.wl.EventQueue) c_int;
pub inline fn dispatchQueue(display: *Display, queue: *client.wl.EventQueue) os.E {
    return os.errno(wl_display_dispatch_queue(display, queue));
}

extern fn wl_display_dispatch_pending(display: *Display) c_int;
pub inline fn dispatchPending(display: *Display) os.E {
    return os.errno(wl_display_dispatch_pending(display));
}

extern fn wl_display_dispatch_queue_pending(display: *Display, queue: *client.wl.EventQueue) c_int;
pub inline fn dispatchQueuePending(display: *Display, queue: *client.wl.EventQueue) os.E {
    return os.errno(wl_display_dispatch_queue_pending(display, queue));
}

extern fn wl_display_roundtrip(display: *Display) c_int;
pub inline fn roundtrip(display: *Display) os.E {
    return os.errno(wl_display_roundtrip(display));
}

extern fn wl_display_roundtrip_queue(display: *Display, queue: *client.wl.EventQueue) c_int;
pub inline fn roundtripQueue(display: *Display, queue: *client.wl.EventQueue) os.E {
    return os.errno(wl_display_roundtrip_queue(display, queue));
}

extern fn wl_display_flush(display: *Display) c_int;
pub inline fn flush(display: *Display) os.E {
    return os.errno(wl_display_flush(display));
}

extern fn wl_display_create_queue(display: *Display) ?*client.wl.EventQueue;
pub inline fn createQueue(display: *Display) error{OutOfMemory}!*client.wl.EventQueue {
    return wl_display_create_queue(display) orelse error.OutOfMemory;
}

extern fn wl_display_get_error(display: *Display) c_int;
pub const getError = wl_display_get_error;

extern fn wl_display_prepare_read_queue(display: *Display, queue: *client.wl.EventQueue) c_int;
/// Succeeds if the queue is empty and returns true.
/// Fails and returns false if the queue was not empty.
pub inline fn prepareReadQueue(display: *Display, queue: *client.wl.EventQueue) bool {
    switch (wl_display_prepare_read_queue(display, queue)) {
        0 => return true,
        -1 => return false,
        else => unreachable,
    }
}

extern fn wl_display_prepare_read(display: *Display) c_int;
/// Succeeds if the queue is empty and returns true.
/// Fails and returns false if the queue was not empty.
pub inline fn prepareRead(display: *Display) bool {
    switch (wl_display_prepare_read(display)) {
        0 => return true,
        -1 => return false,
        else => unreachable,
    }
}

extern fn wl_display_cancel_read(display: *Display) void;
pub const cancelRead = wl_display_cancel_read;

extern fn wl_display_read_events(display: *Display) c_int;
pub inline fn readEvents(display: *Display) os.E {
    return os.errno(wl_display_read_events(display));
}
