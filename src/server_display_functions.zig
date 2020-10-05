const os = @import("std").os;

const util = wayland.util;

extern fn wl_display_create() ?*Display;
pub const create = wl_display_create;

extern fn wl_display_destroy(display: *Display) void;
pub const destroy = wl_display_destroy;

extern fn wl_display_get_event_loop(display: *Display) *util.EventLoop;
pub const getEventLoop = wl_display_get_event_loop;

extern fn wl_display_add_socket(display: *Display, name: [*:0]const u8) c_int;
pub fn addSocket(display: *Display, name: [*:0]const u8) !void {
    if (wl_display_add_socket(display, name) == -1)
        return error.AddSocketFailed;
}

// TODO implement the non-broken version of this
extern fn wl_display_add_socket_auto(display: *Display) ?[*:0]const u8;

extern fn wl_display_add_socket_fd(display: *Display, sock_fd: c_int) c_int;
pub fn addSocketFd(display: *Display, sock_fd: os.fd_t) !void {
    if (wl_display_add_socket_fd(display, sock_fd) == -1)
        return error.AddSocketFailed;
}

extern fn wl_display_terminate(display: *Display) void;
pub const terminate = wl_display_terminate;

extern fn wl_display_run(display: *Display) void;
pub const run = wl_display_run;

extern fn wl_display_flush_clients(display: *Display) void;
pub const flushClients = wl_display_flush_clients;

extern fn wl_display_destroy_clients(display: *Display) void;
pub const destroyClients = wl_display_destroy_clients;

extern fn wl_display_get_serial(display: *Display) u32;
pub const getSerial = wl_display_get_serial;

extern fn wl_display_next_serial(display: *Display) u32;
pub const nextSerial = wl_display_next_serial;

extern fn wl_display_add_destroy_listener(display: *Display, listener: *util.Listener) void;
pub const addDestroyListener = wl_display_add_destroy_listener;

extern fn wl_display_add_client_created_listener(display: *Display, listener: *util.Listener) void;
pub const addClientCreatedListener = wl_display_add_client_created_listener;

extern fn wl_display_get_destroy_listener(display: *Display, notify: util.Listener.NotifyFn) ?*util.Listener;
pub const getDestroyListener = wl_display_get_destroy_listener;

extern fn wl_display_set_global_filter(
    display: *Display,
    filter: fn (client: *const server.Client, global: *const server.Global, data: ?*c_void) bool,
    data: ?*c_void,
) void;
pub fn setGlobalFilter(
    display: *Display,
    comptime T: type,
    filter: fn (client: *const server.Client, global: *const server.Global, data: T) callconv(.C) bool,
    data: T,
) void {
    wl_display_set_global_filter(display, filter, data);
}

extern fn wl_display_get_client_list(display: *Display) *util.List;
pub const getClientList = wl_display_get_client_list;

extern fn wl_display_init_shm(display: *Display) c_int;
pub fn initShm(display: *Display) !void {
    if (wl_display_init_shm(display) == -1)
        return error.GlobalCreateFailed;
}

extern fn wl_display_add_shm_format(display: *Display, format: u32) ?*u32;
pub fn addShmFormat(display: *Display, format: u32) !*u32 {
    return wl_display_add_shm_format(display, format) orelse error.OutOfMemory;
}

extern fn wl_display_add_protocol_logger(
    display: *Display,
    func: fn (data: ?*c_void, direction: server.ProtocolLogger.Type, message: *const server.ProtocolLogger.Message) void,
    data: ?*c_void,
) void;
pub fn addProtocolLogger(
    display: *Display,
    comptime T: type,
    func: fn (data: T, direction: server.ProtocolLogger.Type, message: *const server.ProtocolLogger.Message) callconv(.C) void,
    data: T,
) void {
    wl_display_add_protocol_logger(display, func, data);
}
