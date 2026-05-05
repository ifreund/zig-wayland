const Argument = common.Argument;
const Interface = common.Interface;
const list = common.list;

pub const client = struct {
    const wl = wayland.client.wl;

    extern fn wl_display_cancel_read(display: *wl.Display) void;
    extern fn wl_display_connect_to_fd(fd: c_int) ?*wl.Display;
    extern fn wl_display_connect(name: ?[*:0]const u8) ?*wl.Display;
    extern fn wl_display_create_queue(display: *wl.Display) ?*wl.EventQueue;
    extern fn wl_display_disconnect(display: *wl.Display) void;
    extern fn wl_display_dispatch_pending(display: *wl.Display) c_int;
    extern fn wl_display_dispatch_queue_pending(display: *wl.Display, queue: *wl.EventQueue) c_int;
    extern fn wl_display_dispatch_queue(display: *wl.Display, queue: *wl.EventQueue) c_int;
    extern fn wl_display_dispatch(display: *wl.Display) c_int;
    extern fn wl_display_flush(display: *wl.Display) c_int;
    extern fn wl_display_get_error(display: *wl.Display) c_int;
    extern fn wl_display_get_fd(display: *wl.Display) c_int;
    extern fn wl_display_prepare_read_queue(display: *wl.Display, queue: *wl.EventQueue) c_int;
    extern fn wl_display_prepare_read(display: *wl.Display) c_int;
    extern fn wl_display_read_events(display: *wl.Display) c_int;
    extern fn wl_display_roundtrip_queue(display: *wl.Display, queue: *wl.EventQueue) c_int;
    extern fn wl_display_roundtrip(display: *wl.Display) c_int;
    extern fn wl_event_queue_destroy(queue: *wl.EventQueue) void;
    extern fn wl_proxy_add_dispatcher(
        proxy: *wl.Proxy,
        dispatcher: *const wl.Proxy.DispatcherFn,
        implementation: ?*const anyopaque,
        data: ?*anyopaque,
    ) c_int;
    extern fn wl_proxy_create(factory: *wl.Proxy, interface: *const Interface) ?*wl.Proxy;
    extern fn wl_proxy_destroy(proxy: *wl.Proxy) void;
    extern fn wl_proxy_get_id(proxy: *wl.Proxy) u32;
    extern fn wl_proxy_get_user_data(proxy: *wl.Proxy) ?*anyopaque;
    extern fn wl_proxy_get_version(proxy: *wl.Proxy) u32;
    extern fn wl_proxy_marshal_array_flags(proxy: *wl.Proxy, opcode: u32, interface: ?*const Interface, version: u32, flags: u32, args: ?[*]Argument) ?*wl.Proxy;
    extern fn wl_proxy_set_queue(proxy: *wl.Proxy, queue: *wl.EventQueue) void;
};

pub const cursor = struct {
    const wl = wayland.client.wl;

    extern fn wl_cursor_frame(cursor: *wl.Cursor, time: u32) c_int;
    extern fn wl_cursor_frame_and_duration(cursor: *wl.Cursor, time: u32, duration: *u32) c_int;
    extern fn wl_cursor_image_get_buffer(image: *wl.CursorImage) ?*wl.Buffer;
    extern fn wl_cursor_theme_load(name: ?[*:0]const u8, size: c_int, shm: *wl.Shm) ?*wl.CursorTheme;
    extern fn wl_cursor_theme_destroy(wl_cursor_theme: *wl.CursorTheme) void;
    extern fn wl_cursor_theme_get_cursor(theme: *wl.CursorTheme, name: [*:0]const u8) ?*wl.Cursor;
};

pub const egl = struct {
    const wl = wayland.client.wl;

    extern fn wl_egl_window_create(surface: *wl.Surface, width: c_int, height: c_int) ?*wl.EglWindow;
    extern fn wl_egl_window_destroy(egl_window: *wl.EglWindow) void;
    extern fn wl_egl_window_resize(egl_window: *wl.EglWindow, width: c_int, height: c_int, dx: c_int, dy: c_int) void;
    extern fn wl_egl_window_get_attached_size(egl_window: *wl.EglWindow, width: *c_int, height: *c_int) void;
};

pub const server = struct {
    const wl = wayland.server.wl;

    extern fn wl_display_create() ?*wl.Server;
    extern fn wl_display_destroy(_server: *wl.Server) void;
    extern fn wl_display_get_event_loop(_server: *wl.Server) *wl.EventLoop;
    extern fn wl_display_add_socket(_server: *wl.Server, name: [*:0]const u8) c_int;
    extern fn wl_display_add_socket_fd(_server: *wl.Server, sock_fd: c_int) c_int;
    extern fn wl_display_terminate(_server: *wl.Server) void;
    extern fn wl_display_run(_server: *wl.Server) void;
    extern fn wl_display_flush_clients(_server: *wl.Server) void;
    extern fn wl_display_destroy_clients(_server: *wl.Server) void;
    extern fn wl_display_get_serial(_server: *wl.Server) u32;
    extern fn wl_display_next_serial(_server: *wl.Server) u32;
    extern fn wl_display_add_destroy_listener(_server: *wl.Server, listener: *wl.Listener(*wl.Server)) void;
    extern fn wl_display_add_client_created_listener(_server: *wl.Server, listener: *wl.Listener(*wl.Client)) void;
    extern fn wl_display_set_global_filter(
        server: *wl.Server,
        filter: *const fn (_client: *const wl.Client, global: *const wl.Global, data: ?*anyopaque) callconv(.c) bool,
        data: ?*anyopaque,
    ) void;
    extern fn wl_display_get_client_list(_server: *wl.Server) *list.Head(wl.Client, null);
    extern fn wl_display_init_shm(_server: *wl.Server) c_int;
    extern fn wl_display_add_shm_format(_server: *wl.Server, format: u32) ?*u32;
    extern fn wl_display_add_protocol_logger(
        _server: *wl.Server,
        func: *const fn (data: ?*anyopaque, direction: wl.ProtocolLogger.Type, message: *const wl.ProtocolLogger.LogMessage) callconv(.c) void,
        data: ?*anyopaque,
    ) void;
    extern fn wl_client_create(_server: *wl.Server, fd: c_int) ?*wl.Client;
    extern fn wl_client_destroy(_client: *wl.Client) void;
    extern fn wl_client_flush(_client: *wl.Client) void;
    extern fn wl_client_get_link(_client: *wl.Client) *list.Link;
    extern fn wl_client_from_link(link: *list.Link) *wl.Client;
    extern fn wl_client_get_credentials(_client: *wl.Client, pid: *posix.pid_t, uid: *posix.uid_t, gid: *posix.gid_t) void;
    extern fn wl_client_add_destroy_listener(_client: *wl.Client, listener: *wl.Listener(*wl.Client)) void;
    extern fn wl_client_get_object(_client: *wl.Client, id: u32) ?*wl.Resource;
    extern fn wl_client_post_no_memory(_client: *wl.Client) void;
    extern fn wl_client_post_implementation_error(_client: *wl.Client, msg: [*:0]const u8, ...) void;
    extern fn wl_client_add_resource_created_listener(_client: *wl.Client, listener: *wl.Listener(*wl.Resource)) void;
    extern fn wl_client_for_each_resource(
        _client: *wl.Client,
        iterator: *const fn (resource: *wl.Resource, data: ?*anyopaque) callconv(.c) wl.IteratorResult,
        data: ?*anyopaque,
    ) void;
    extern fn wl_client_get_fd(_client: *wl.Client) c_int;
    extern fn wl_client_get_display(_client: *wl.Client) *wl.Server;
    extern fn wl_global_create(
        _server: *wl.Server,
        interface: *const Interface,
        version: c_int,
        data: ?*anyopaque,
        bind: *const fn (_client: *wl.Client, data: ?*anyopaque, version: u32, id: u32) callconv(.c) void,
    ) ?*wl.Global;
    extern fn wl_global_remove(global: *wl.Global) void;
    extern fn wl_global_destroy(global: *wl.Global) void;
    extern fn wl_global_get_interface(global: *const wl.Global) *const Interface;
    extern fn wl_global_get_name(global: *const wl.Global, _client: *const wl.Client) u32;
    extern fn wl_global_get_user_data(global: *const wl.Global) ?*anyopaque;
    extern fn wl_resource_create(_client: *wl.Client, interface: *const Interface, version: c_int, id: u32) ?*wl.Resource;
    extern fn wl_resource_destroy(resource: *wl.Resource) void;
    extern fn wl_resource_post_event_array(resource: *wl.Resource, opcode: u32, args: ?[*]Argument) void;
    extern fn wl_resource_queue_event_array(resource: *wl.Resource, opcode: u32, args: ?[*]Argument) void;
    extern fn wl_resource_post_error(resource: *wl.Resource, code: u32, message: [*:0]const u8, ...) void;
    extern fn wl_resource_post_no_memory(resource: *wl.Resource) void;
    extern fn wl_resource_set_dispatcher(
        resource: *wl.Resource,
        dispatcher: ?*const wl.Resource.DispatcherFn,
        implementation: ?*const anyopaque,
        data: ?*anyopaque,
        destroy_fn: ?*const wl.Resource.DestroyFn,
    ) void;
    extern fn wl_resource_get_user_data(resource: *wl.Resource) ?*anyopaque;
    extern fn wl_resource_get_id(resource: *wl.Resource) u32;
    extern fn wl_resource_get_link(resource: *wl.Resource) *list.Link;
    extern fn wl_resource_from_link(link: *list.Link) *wl.Resource;
    extern fn wl_resource_find_for_client(_list: *list.Head(wl.Resource, null), _client: *wl.Client) ?*wl.Resource;
    extern fn wl_resource_get_client(resource: *wl.Resource) *wl.Client;
    extern fn wl_resource_get_version(resource: *wl.Resource) c_int;
    extern fn wl_resource_get_class(resource: *wl.Resource) [*:0]const u8;
    extern fn wl_resource_add_destroy_listener(resource: *wl.Resource, listener: *wl.Listener(*wl.Resource)) void;
    extern fn wl_protocol_logger_destroy(logger: *wl.ProtocolLogger) void;
    extern fn wl_event_loop_create() ?*wl.EventLoop;
    extern fn wl_event_loop_destroy(loop: *wl.EventLoop) void;
    extern fn wl_event_loop_add_fd(
        loop: *wl.EventLoop,
        fd: c_int,
        mask: u32,
        func: *const fn (fd: c_int, mask: u32, data: ?*anyopaque) callconv(.c) c_int,
        data: ?*anyopaque,
    ) ?*wl.EventSource;
    extern fn wl_event_loop_add_timer(
        loop: *wl.EventLoop,
        func: *const fn (data: ?*anyopaque) callconv(.c) c_int,
        data: ?*anyopaque,
    ) ?*wl.EventSource;
    extern fn wl_event_loop_add_signal(
        loop: *wl.EventLoop,
        signal_number: c_int,
        func: *const fn (c_int, ?*anyopaque) callconv(.c) c_int,
        data: ?*anyopaque,
    ) ?*wl.EventSource;
    extern fn wl_event_loop_add_idle(
        loop: *wl.EventLoop,
        func: *const fn (data: ?*anyopaque) callconv(.c) void,
        data: ?*anyopaque,
    ) ?*wl.EventSource;
    extern fn wl_event_loop_dispatch(loop: *wl.EventLoop, timeout: c_int) c_int;
    extern fn wl_event_loop_dispatch_idle(loop: *wl.EventLoop) void;
    extern fn wl_event_loop_get_fd(loop: *wl.EventLoop) c_int;
    extern fn wl_event_loop_add_destroy_listener(loop: *wl.EventLoop, listener: *wl.Listener(*wl.EventLoop)) void;
    extern fn wl_event_source_remove(source: *wl.EventSource) c_int;
    extern fn wl_event_source_check(source: *wl.EventSource) void;
    extern fn wl_event_source_fd_update(source: *wl.EventSource, mask: u32) c_int;
    extern fn wl_event_source_timer_update(source: *wl.EventSource, ms_delay: c_int) c_int;
    extern fn wl_shm_buffer_get(resource: *wl.Resource) ?*wl.shm.Buffer;
    extern fn wl_shm_buffer_begin_access(buffer: *wl.shm.Buffer) void;
    extern fn wl_shm_buffer_end_access(buffer: *wl.shm.Buffer) void;
    extern fn wl_shm_buffer_get_data(buffer: *wl.shm.Buffer) ?*anyopaque;
    extern fn wl_shm_buffer_get_format(buffer: *wl.shm.Buffer) u32;
    extern fn wl_shm_buffer_get_height(buffer: *wl.shm.Buffer) i32;
    extern fn wl_shm_buffer_get_width(buffer: *wl.shm.Buffer) i32;
    extern fn wl_shm_buffer_get_stride(buffer: *wl.shm.Buffer) i32;
    extern fn wl_shm_buffer_ref_pool(buffer: *wl.shm.Buffer) *wl.Pool;
    extern fn wl_shm_pool_unref(pool: *wl.Pool) void;
};
