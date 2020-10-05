const std = @import("std");
const os = std.os;

const wayland = @import("wayland.zig");
const common = wayland.common;

pub const Client = opaque {};

pub const Global = opaque {
    extern fn wl_global_create(
        display: *wl.Display,
        interface: *const common.Interface,
        version: c_int,
        data: ?*c_void,
        bind: fn (client: *Client, data: ?*c_void, version: u32, id: u32) callconv(.C) void,
    ) void;
    pub fn create(
        display: *wl.Display,
        comptime ObjectT: type,
        version: u32,
        comptime T: type,
        data: T,
        bind: fn (client: *Client, data: T, version: u32, id: u32) callconv(.C) void,
    ) void {
        wl_global_create(display, ObjectT.interface, version, data, bind);
    }

    extern fn wl_global_remove(global: *Global) void;
    pub fn remove(global: *Global) void {
        wl_global_remove(global);
    }

    extern fn wl_global_destroy(global: *Global) void;
    pub fn destroy(global: *Global) void {
        wl_global_destroy(global);
    }
};

pub const Resource = opaque {
    extern fn wl_resource_post_event_array(resource: *Resource, opcode: u32, args: [*]common.Argument) void;
    pub fn postEvent(resource: *Resource, opcode: u32, args: [*]common.Argument) void {
        wl_resource_post_event_array(resource, opcode, args);
    }

    extern fn wl_resource_queue_event_array(resource: *Resource, opcode: u32, args: [*]common.Argument) void;
    pub fn queueEvent(resource: *Resource, opcode: u32, args: [*]common.Argument) void {
        wl_resource_queue_event_array(resource, opcode, args);
    }

    extern fn wl_resource_post_error(resource: *Resource, code: u32, message: [*:0]const u8, ...) void;
    pub fn postError(resource: *Resource, code: u32, message: [*:0]const u8) void {
        wl_resource_post_error(resource, code, message);
    }

    extern fn wl_resource_post_no_memory(resource: *Resource) void;
    pub fn postNoMemory(resource: *Resource) void {
        wl_resource_post_no_memory(resource);
    }

    const DispatcherFn = fn (
        implementation: ?*const c_void,
        resource: *Resource,
        opcode: u32,
        message: *const common.Message,
        args: [*]common.Argument,
    ) callconv(.C) c_int;
    const DestroyFn = fn (resource: *Resource) callconv(.C) void;
    extern fn wl_resource_set_dispatcher(
        resource: *Resource,
        dispatcher: DispatcherFn,
        implementation: ?*const c_void,
        data: ?*c_void,
        destroy: DestroyFn,
    ) void;
    pub fn setDispatcher(
        resource: *Resource,
        dispatcher: DispatcherFn,
        implementation: ?*const c_void,
        data: ?*c_void,
        destroy: DestroyFn,
    ) !void {
        if (wl_proxy_add_dispatcher(proxy, dispatcher, implementation, data) == -1)
            return error.AlreadyHasListener;
    }

    extern fn wl_resource_destroy(resource: *Resource) void;
    pub fn destroy(resource: *Resource) void {
        wl_resource_destroy(resource);
    }

    extern fn wl_resource_get_user_data(resource: *Resource) ?*c_void;
    pub fn getUserData(resource: *Resource) ?*c_void {
        return wl_resource_get_user_data(resource);
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

pub const Listener = extern struct {
    pub const NotifyFn = fn (listener: *Listener, data: ?*c_void) callconv(.C) void;

    link: common.List,
    notify: NotifyFn,
};

pub const Signal = extern struct {
    listener_list: common.List,

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
