const assert = @import("std").debug.assert;
const client = @import("wayland.zig").client;
const common = @import("common.zig");
pub const Object = common.Object;
pub const Message = common.Message;
pub const Interface = common.Interface;
pub const Array = common.Array;
pub const Fixed = common.Fixed;
pub const Argument = common.Argument;

pub const Proxy = opaque {
    extern fn wl_proxy_create(factory: *Proxy, interface: *const Interface) ?*Proxy;
    pub fn create(factory: *Proxy, interface: *const Interface) error{OutOfMemory}!*Proxy {
        return wl_proxy_create(factory, interface) orelse error.OutOfMemory;
    }

    extern fn wl_proxy_destroy(proxy: *Proxy) void;
    pub const destroy = wl_proxy_destroy;

    extern fn wl_proxy_marshal_array(proxy: *Proxy, opcode: u32, args: ?[*]Argument) void;
    pub const marshal = wl_proxy_marshal_array;

    extern fn wl_proxy_marshal_array_constructor(
        proxy: *Proxy,
        opcode: u32,
        args: [*]Argument,
        interface: *const Interface,
    ) ?*Proxy;
    pub fn marshalConstructor(
        proxy: *Proxy,
        opcode: u32,
        args: [*]Argument,
        interface: *const Interface,
    ) error{OutOfMemory}!*Proxy {
        return wl_proxy_marshal_array_constructor(proxy, opcode, args, interface) orelse
            error.OutOfMemory;
    }

    extern fn wl_proxy_marshal_array_constructor_versioned(
        proxy: *Proxy,
        opcode: u32,
        args: [*]Argument,
        interface: *const Interface,
        version: u32,
    ) ?*Proxy;
    pub fn marshalConstructorVersioned(
        proxy: *Proxy,
        opcode: u32,
        args: [*]Argument,
        interface: *const Interface,
        version: u32,
    ) error{OutOfMemory}!*Proxy {
        return wl_proxy_marshal_array_constructor_versioned(proxy, opcode, args, interface, version) orelse
            error.OutOfMemory;
    }

    const DispatcherFn = fn (
        implementation: ?*const anyopaque,
        proxy: *Proxy,
        opcode: u32,
        message: *const Message,
        args: [*]Argument,
    ) callconv(.C) c_int;
    extern fn wl_proxy_add_dispatcher(
        proxy: *Proxy,
        dispatcher: *const DispatcherFn,
        implementation: ?*const anyopaque,
        data: ?*anyopaque,
    ) c_int;
    pub fn addDispatcher(
        proxy: *Proxy,
        dispatcher: *const DispatcherFn,
        implementation: ?*const anyopaque,
        data: ?*anyopaque,
    ) void {
        const ret = wl_proxy_add_dispatcher(proxy, dispatcher, implementation, data);
        // Since there is no way to remove listeners, adding a listener to
        // the same proxy twice is always a bug, so assert instead of returning
        // an error.
        assert(ret != -1); // If this fails, a listener was already added
    }

    extern fn wl_proxy_get_user_data(proxy: *Proxy) ?*anyopaque;
    pub const getUserData = wl_proxy_get_user_data;

    extern fn wl_proxy_get_version(proxy: *Proxy) u32;
    pub const getVersion = wl_proxy_get_version;

    extern fn wl_proxy_get_id(proxy: *Proxy) u32;
    pub const getId = wl_proxy_get_id;

    extern fn wl_proxy_set_queue(proxy: *Proxy, queue: *EventQueue) void;
    pub const setQueue = wl_proxy_set_queue;
};

pub const EventQueue = opaque {
    extern fn wl_event_queue_destroy(queue: *EventQueue) void;
    pub const destroy = wl_event_queue_destroy;
};

pub const EglWindow = opaque {
    extern fn wl_egl_window_create(surface: *client.wl.Surface, width: c_int, height: c_int) ?*EglWindow;
    pub fn create(surface: *client.wl.Surface, width: c_int, height: c_int) !*EglWindow {
        // Why do people use int when they require a positive number?
        assert(width > 0 and height > 0);
        return wl_egl_window_create(surface, width, height) orelse error.OutOfMemory;
    }

    extern fn wl_egl_window_destroy(egl_window: *EglWindow) void;
    pub const destroy = wl_egl_window_destroy;

    extern fn wl_egl_window_resize(egl_window: *EglWindow, width: c_int, height: c_int, dx: c_int, dy: c_int) void;
    pub const resize = wl_egl_window_resize;

    extern fn wl_egl_window_get_attached_size(egl_window: *EglWindow, width: *c_int, height: *c_int) void;
    pub const getAttachedSize = wl_egl_window_get_attached_size;
};

pub const CursorTheme = opaque {
    extern fn wl_cursor_theme_load(name: ?[*:0]const u8, size: c_int, shm: *client.wl.Shm) ?*CursorTheme;
    pub fn load(name: ?[*:0]const u8, size: i32, shm: *client.wl.Shm) error{LoadThemeFailed}!*CursorTheme {
        return wl_cursor_theme_load(name, @intCast(c_int, size), shm) orelse error.LoadThemeFailed;
    }

    extern fn wl_cursor_theme_destroy(wl_cursor_theme: *CursorTheme) void;
    pub const destroy = wl_cursor_theme_destroy;

    extern fn wl_cursor_theme_get_cursor(theme: *CursorTheme, name: [*:0]const u8) ?*Cursor;
    pub const getCursor = wl_cursor_theme_get_cursor;
};

pub const Cursor = extern struct {
    image_count: c_uint,
    images: [*]*CursorImage,
    name: [*:0]u8,

    extern fn wl_cursor_frame(cursor: *Cursor, time: u32) c_int;
    pub const frame = wl_cursor_frame;

    extern fn wl_cursor_frame_and_duration(cursor: *Cursor, time: u32, duration: *u32) c_int;
    pub const frameAndDuration = wl_cursor_frame_and_duration;
};

pub const CursorImage = extern struct {
    width: u32,
    height: u32,
    hotspot_x: u32,
    hotspot_y: u32,
    delay: u32,

    extern fn wl_cursor_image_get_buffer(image: *CursorImage) ?*client.wl.Buffer;
    pub fn getBuffer(image: *CursorImage) error{OutOfMemory}!*client.wl.Buffer {
        return wl_cursor_image_get_buffer(image) orelse error.OutOfMemory;
    }
};
