const std = @import("std");
const os = std.os;

pub const List = extern struct {
    prev: *List,
    next: *List,

    pub fn init(list: *List) void {
        list.* = .{ .prev = list, .next = list };
    }

    pub fn prepend(list: *List, elm: *List) void {
        elm.prev = list;
        elm.next = list.next;
        list.next = elm;
        elm.next.prev = elm;
    }

    pub fn append(list: *List, elm: *List) void {
        list.prev.prepend(elm);
    }

    pub fn remove(elm: *elm) void {
        elm.prev.next = elm.next;
        elm.next.prev = elm.prev;
        elm = undefined;
    }

    pub fn length(list: *const List) usize {
        var count: usize = 0;
        var current = list.next;
        while (current != list) : (current = current.next) {
            count += 1;
        }
        return count;
    }

    pub fn empty(list: *const List) bool {
        return list.next == list;
    }

    pub fn insertList(list: *List, other: *List) void {
        if (other.empty()) return;
        other.next.prev = list;
        other.prev.next = list.next;
        list.next.prev = other.prev;
        list.next = other.next;
    }
};

pub const Listener = extern struct {
    pub const NotifyFn = fn (listener: *Listener, data: ?*c_void) callconv(.C) void;

    link: List,
    notify: NotifyFn,
};

pub const Signal = extern struct {
    listener_list: List,

    pub fn init(signal: *Signal) void {
        signal.listener_list.init();
    }

    pub fn add(signal: *Signal, listener: *Listener) void {
        signal.listener_list.append(&listener.link);
    }

    pub fn get(signal: *Signal, notify: Listener.NotifyFn) ?*Listener {
        // TODO
    }

    pub fn emit(signal: *Signal, data: ?*c_void) void {
        //TODO
    }
};

pub const EventLoop = opaque {
    extern fn wl_event_loop_create() ?*EventLoop;
    pub fn create() ?*EventLoop {
        return wl_event_loop_create();
    }

    extern fn wl_event_loop_destroy(loop: *EventLoop) void;
    pub fn destroy(loop: *EventLoop) void {
        wl_event_loop_destroy(loop);
    }

    extern fn wl_event_loop_add_fd(
        loop: *EventLoop,
        fd: os.fd_t,
        mask: u32,
        func: fn (fd: os.fd_t, mask: u32, data: ?*c_void) c_int,
        data: ?*c_void,
    ) ?*EventSource;
    pub fn addFd(
        loop: *EventLoop,
        comptime T: type,
        fd: os.fd_t,
        mask: u32,
        func: fn (fd: os.fd_t, mask: u32, data: T) callconv(.C) c_int,
        data: T,
    ) ?*EventSource {
        return wl_event_loop_add_fd(loop, fd, mask, func, data);
    }

    extern fn wl_event_loop_add_timer(
        loop: *EventLoop,
        func: fn (data: ?*c_void) c_int,
        data: ?*c_void,
    ) ?*EventSource;
    pub fn addTimer(
        loop: *EventLoop,
        comptime T: type,
        func: fn (data: T) callconv(.C) c_int,
        data: T,
    ) ?*EventSource {
        return wl_event_loop_add_timer(loop, func, data);
    }

    extern fn wl_event_loop_add_signal(
        loop: *EventLoop,
        signal_number: c_int,
        func: fn (c_int, ?*c_void) c_int,
        data: ?*c_void,
    ) ?*EventSource;
    pub fn addSignal(
        loop: *EventLoop,
        comptime T: type,
        signal_number: c_int,
        func: fn (signal_number: c_int, data: T) callconv(.C) c_int,
        data: T,
    ) ?*EventSource {
        return wl_event_loop_add_signal(loop, signal_number, func, data);
    }

    extern fn wl_event_loop_add_idle(
        loop: *EventLoop,
        func: fn (data: ?*c_void) c_int,
        data: ?*c_void,
    ) ?*EventSource;
    pub fn addIdle(
        loop: *EventLoop,
        comptime T: type,
        func: fn (data: T) callconv(.C) c_int,
        data: T,
    ) error{OutOfMemory}!*EventSource {
        return wl_event_loop_add_idle(loop, func, data) orelse error.OutOfMemory;
    }

    extern fn wl_event_loop_dispatch(loop: *EventLoop, timeout: c_int) c_int;
    pub fn dispatch(loop: *EventLoop, timeout: c_int) !void {
        const rc = wl_event_loop_dispatch(loop, timeout);
        switch (os.errno(rc)) {
            0 => return,
            // TODO
            else => |err| os.unexpectedErrno(err),
        }
    }

    extern fn wl_event_loop_dispatch_idle(loop: *EventLoop) void;
    pub fn dispatchIdle(loop: *EventLoop) void {
        wl_event_loop_dispatch_idle(loop);
    }

    extern fn wl_event_loop_get_fd(loop: *EventLoop) c_int;
    pub fn getFd(loop: *EventLoop) os.fd_t {
        return wl_event_loop_get_fd(loop);
    }

    extern fn wl_event_loop_add_destroy_listener(loop: *EventLoop, listener: *Listener) void;
    pub fn addDestroyListener(loop: *EventLoop, listener: *Listener) void {
        wl_event_loop_add_destroy_listener(loop, listener);
    }

    extern fn wl_event_loop_get_destroy_listener(loop: *EventLoop, notify: Listener.NotifyFn) ?*Listener;
    pub fn getDestroyListener(loop: *EventLoop, notify: Listener.NotifyFn) ?*Listener {
        return wl_event_loop_get_destroy_listener(loop, notify);
    }
};

pub const EventSource = opaque {
    extern fn wl_event_source_remove(source: *EventSource) c_int;
    pub fn remove(source: *EventSource) void {
        if (wl_event_source_remove(source) != 0) unreachable;
    }

    extern fn wl_event_source_check(source: *EventSource) void;
    pub fn check(source: *EventSource) void {
        wl_event_source_check(source);
    }

    extern fn wl_event_source_fd_update(source: *EventSource, mask: u32) c_int;
    pub fn fdUpdate(source: *EventSource, mask: u32) !void {
        const rc = wl_event_source_fd_update(source, mask);
        switch (os.errno(rc)) {
            0 => return,
            // TODO
            else => |err| os.unexpectedErrno(err),
        }
    }

    extern fn wl_event_source_timer_update(source: *EventSource, ms_delay: c_int) c_int;
    pub fn timerUpdate(source: *EventSource, ms_delay: u31) !void {
        const rc = wl_event_source_timer_update(source, ms_delay);
        switch (os.errno(rc)) {
            0 => return,
            // TODO
            else => |err| os.unexpectedErrno(err),
        }
    }
};
