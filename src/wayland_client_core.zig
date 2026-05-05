pub const Object = common.Object;
pub const Message = common.Message;
pub const Interface = common.Interface;
pub const list = common.list;
pub const Array = common.Array;
pub const Fixed = common.Fixed;
pub const Argument = common.Argument;

pub const Proxy = opaque {
    pub inline fn create(factory: *Proxy, interface: *const Interface) error{OutOfMemory}!*Proxy {
        return ffi.client.wl_proxy_create(factory, interface) orelse error.OutOfMemory;
    }

    pub inline fn destroy(proxy: *Proxy) void {
        ffi.client.wl_proxy_destroy(proxy);
    }

    pub const MarshalFlags = packed struct(u32) {
        destroy: bool = false,
        _: u31 = 0,
    };

    pub inline fn marshal(proxy: *wl.Proxy, opcode: u32, interface: ?*const Interface, version: u32, flags: MarshalFlags, args: ?[*]Argument) ?*Proxy {
        return ffi.client.wl_proxy_marshal_array_flags(proxy, opcode, interface, version, @bitCast(flags), args);
    }

    pub const DispatcherFn = fn (
        implementation: ?*const anyopaque,
        proxy: *Proxy,
        opcode: u32,
        message: *const Message,
        args: [*]Argument,
    ) callconv(.c) c_int;
    pub inline fn addDispatcher(
        proxy: *Proxy,
        dispatcher: *const DispatcherFn,
        implementation: ?*const anyopaque,
        data: ?*anyopaque,
    ) void {
        const ret = ffi.client.wl_proxy_add_dispatcher(proxy, dispatcher, implementation, data);
        // Since there is no way to remove listeners, adding a listener to
        // the same proxy twice is always a bug, so assert instead of returning
        // an error.
        assert(ret != -1); // If this fails, a listener was already added
    }

    pub inline fn getUserData(proxy: *Proxy) ?*anyopaque {
        return ffi.client.wl_proxy_get_user_data(proxy);
    }

    pub inline fn getVersion(proxy: *Proxy) u32 {
        return ffi.client.wl_proxy_get_version(proxy);
    }

    pub inline fn getId(proxy: *Proxy) u32 {
        return ffi.client.wl_proxy_get_id(proxy);
    }

    pub inline fn setQueue(proxy: *Proxy, queue: *EventQueue) void {
        ffi.client.wl_proxy_set_queue(proxy, queue);
    }
};

pub const EventQueue = opaque {
    pub inline fn destroy(queue: *EventQueue) void {
        ffi.client.wl_event_queue_destroy(queue);
    }
};

pub const EglWindow = opaque {
    pub inline fn create(surface: *client.wl.Surface, width: c_int, height: c_int) error{OutOfMemory}!*EglWindow {
        // Why do people use int when they require a positive number?
        assert(width > 0 and height > 0);
        return ffi.egl.wl_egl_window_create(surface, width, height) orelse error.OutOfMemory;
    }

    pub inline fn destroy(egl_window: *EglWindow) void {
        ffi.egl.wl_egl_window_destroy(egl_window);
    }

    pub inline fn resize(egl_window: *EglWindow, width: c_int, height: c_int, dx: c_int, dy: c_int) void {
        ffi.egl.wl_egl_window_resize(egl_window, width, height, dx, dy);
    }

    pub inline fn getAttachedSize(egl_window: *EglWindow, width: *c_int, height: *c_int) void {
        ffi.egl.wl_egl_window_get_attached_size(egl_window, width, height);
    }
};

pub const CursorTheme = opaque {
    pub inline fn load(name: ?[*:0]const u8, size: i32, shm: *client.wl.Shm) error{LoadThemeFailed}!*CursorTheme {
        return ffi.cursor.wl_cursor_theme_load(name, @intCast(size), shm) orelse error.LoadThemeFailed;
    }

    pub inline fn destroy(wl_cursor_theme: *CursorTheme) void {
        ffi.cursor.wl_cursor_theme_destroy(wl_cursor_theme);
    }

    pub inline fn getCursor(theme: *CursorTheme, name: [*:0]const u8) ?*Cursor {
        return ffi.cursor.wl_cursor_theme_get_cursor(theme, name);
    }
};

pub const Cursor = extern struct {
    image_count: c_uint,
    images: [*]*CursorImage,
    name: [*:0]u8,

    pub inline fn frame(cursor: *Cursor, time: u32) c_int {
        return ffi.cursor.wl_cursor_frame(cursor, time);
    }

    pub inline fn frameAndDuration(cursor: *Cursor, time: u32, duration: *u32) c_int {
        return ffi.cursor.wl_cursor_frame_and_duration(cursor, time, duration);
    }
};

pub const CursorImage = extern struct {
    width: u32,
    height: u32,
    hotspot_x: u32,
    hotspot_y: u32,
    delay: u32,

    pub inline fn getBuffer(image: *CursorImage) error{OutOfMemory}!*client.wl.Buffer {
        return ffi.cursor.wl_cursor_image_get_buffer(image) orelse error.OutOfMemory;
    }
};
