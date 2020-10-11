const os = @import("std").os;

const wayland = @import("wayland.zig");
const common = wayland.common;

/// This is wayland-server's wl_display. It has been renamed as zig-wayland has
/// decided to hide wl_resources with opaque pointers in the same way that
/// wayland-client does with wl_proxys. This of course creates a name conflict.
pub const Server = opaque {
    extern fn wl_display_create() ?*Server;
    pub fn create() !*Server {
        return wl_display_create() orelse error.ServerCreateFailed;
    }

    extern fn wl_display_destroy(server: *Server) void;
    pub const destroy = wl_display_destroy;

    extern fn wl_display_get_event_loop(server: *Server) *EventLoop;
    pub const getEventLoop = wl_display_get_event_loop;

    extern fn wl_display_add_socket(server: *Server, name: [*:0]const u8) c_int;
    pub fn addSocket(server: *Server, name: [*:0]const u8) !void {
        if (wl_display_add_socket(display, name) == -1)
            return error.AddSocketFailed;
    }

    // TODO implement the non-broken version of this
    extern fn wl_display_add_socket_auto(server: *Server) ?[*:0]const u8;

    extern fn wl_display_add_socket_fd(server: *Server, sock_fd: c_int) c_int;
    pub fn addSocketFd(server: *Server, sock_fd: os.fd_t) !void {
        if (wl_display_add_socket_fd(display, sock_fd) == -1)
            return error.AddSocketFailed;
    }

    extern fn wl_display_terminate(server: *Server) void;
    pub const terminate = wl_display_terminate;

    extern fn wl_display_run(server: *Server) void;
    pub const run = wl_display_run;

    extern fn wl_display_flush_clients(server: *Server) void;
    pub const flushClients = wl_display_flush_clients;

    extern fn wl_display_destroy_clients(server: *Server) void;
    pub const destroyClients = wl_display_destroy_clients;

    extern fn wl_display_get_serial(server: *Server) u32;
    pub const getSerial = wl_display_get_serial;

    extern fn wl_display_next_serial(server: *Server) u32;
    pub const nextSerial = wl_display_next_serial;

    extern fn wl_display_add_destroy_listener(server: *Server, listener: *Listener) void;
    pub const addDestroyListener = wl_display_add_destroy_listener;

    extern fn wl_display_add_client_created_listener(server: *Server, listener: *Listener) void;
    pub const addClientCreatedListener = wl_display_add_client_created_listener;

    extern fn wl_display_get_destroy_listener(server: *Server, notify: Listener.NotifyFn) ?*Listener;
    pub const getDestroyListener = wl_display_get_destroy_listener;

    extern fn wl_display_set_global_filter(
        server: *Server,
        filter: fn (client: *const Client, global: *const Global, data: ?*c_void) bool,
        data: ?*c_void,
    ) void;
    pub fn setGlobalFilter(
        server: *Server,
        comptime T: type,
        filter: fn (client: *const Client, global: *const Global, data: T) callconv(.C) bool,
        data: T,
    ) void {
        wl_display_set_global_filter(display, filter, data);
    }

    extern fn wl_display_get_client_list(server: *Server) *List;
    pub const getClientList = wl_display_get_client_list;

    extern fn wl_display_init_shm(server: *Server) c_int;
    pub fn initShm(server: *Server) !void {
        if (wl_display_init_shm(display) == -1)
            return error.GlobalCreateFailed;
    }

    extern fn wl_display_add_shm_format(server: *Server, format: u32) ?*u32;
    pub fn addShmFormat(server: *Server, format: u32) !*u32 {
        return wl_display_add_shm_format(display, format) orelse error.OutOfMemory;
    }

    extern fn wl_display_add_protocol_logger(
        server: *Server,
        func: fn (data: ?*c_void, direction: ProtocolLogger.Type, message: *const ProtocolLogger.Message) void,
        data: ?*c_void,
    ) void;
    pub fn addProtocolLogger(
        server: *Server,
        comptime T: type,
        func: fn (data: T, direction: ProtocolLogger.Type, message: *const ProtocolLogger.Message) callconv(.C) void,
        data: T,
    ) void {
        wl_display_add_protocol_logger(display, func, data);
    }
};

pub const Client = opaque {
    extern fn wl_client_create(server: *Server, fd: os.fd_t) ?*Client;
    pub const create = wl_client_create;

    extern fn wl_client_destroy(client: *Client) void;
    pub const destroy = wl_client_destroy;

    extern fn wl_client_flush(client: *Client) void;
    pub const flush = wl_client_flush;

    extern fn wl_client_get_link(client: *Client) *List;
    pub const getLink = wl_client_get_link;

    extern fn wl_client_from_link(link: *List) *Client;
    pub const fromLink = wl_client_from_link;

    const Credentials = struct {
        pid: os.pid_t,
        gid: os.gid_t,
        uid: os.uid_t,
    };
    extern fn wl_client_get_credentials(client: *Client, pid: *os.pid_t, uid: *os.uid_t, gid: *os.gid_t) void;
    pub fn getCredentials(client: *Client) Credentials {
        var credentials: Credentials = undefined;
        wl_client_get_credentials(client, &credentials.pid, &credentials.uid, &credentials.gid);
        return credentials;
    }

    extern fn wl_client_add_destroy_listener(client: *Client, listener: *Listener) void;
    pub const addDestroyListener = wl_client_add_destroy_listener;

    extern fn wl_client_get_destroy_listener(client: *Client, notify: Listener.NotifyFn) ?*Listener;
    pub const getDestroyListener = wl_client_get_destroy_listener;

    extern fn wl_client_get_object(client: *Client, id: u32) ?*Resource;
    pub const getObject = wl_client_get_object;

    extern fn wl_client_post_no_memory(client: *Client) void;
    pub const postNoMemory = wl_client_post_no_memory;

    extern fn wl_client_post_implementation_error(client: *Client, msg: [*:0]const u8, ...) void;
    pub const postImplementationError = wl_client_post_implementation_error;

    extern fn wl_client_add_resource_created_listener(client: *Client, listener: *Listener) void;
    pub const addResourceCreatedListener = wl_client_add_resource_created_listener;

    const IteratorResult = extern enum { stop, cont };
    extern fn wl_client_for_each_resource(
        client: *Client,
        iterator: fn (resource: *Resource, data: ?*c_void) IteratorResult,
        data: ?*c_void,
    ) void;
    pub fn forEachResource(
        client: *Client,
        comptime T: type,
        iterator: fn (resource: *Resource, data: T) callconv(.C) IteratorResult,
        data: T,
    ) void {
        wl_client_for_each_resource(client, iterator, data);
    }

    extern fn wl_client_get_fd(client: *Client) os.fd_t;
    pub const getFd = wl_client_get_fd;

    extern fn wl_client_get_display(client: *Client) *Server;
    pub const getDisplay = wl_client_get_display;
};

pub const Global = opaque {
    extern fn wl_global_create(
        server: *Server,
        interface: *const common.Interface,
        version: c_int,
        data: ?*c_void,
        bind: fn (client: *Client, data: ?*c_void, version: u32, id: u32) callconv(.C) void,
    ) ?*Global;
    pub fn create(
        server: *Server,
        comptime Object: type,
        version: u32,
        comptime T: type,
        data: T,
        bind: fn (client: *Client, data: T, version: u32, id: u32) callconv(.C) void,
    ) !*Global {
        return wl_global_create(display, Object.interface, version, data, bind) orelse
            error.GlobalCreateFailed;
    }

    extern fn wl_global_remove(global: *Global) void;
    pub const remove = wl_global_remove;

    extern fn wl_global_destroy(global: *Global) void;
    pub const destroy = wl_global_destroy;

    extern fn wl_global_get_interface(global: *const Global) *const common.Interface;
    pub const getInterface = wl_global_get_interface;

    extern fn wl_global_get_user_data(global: *const Global) ?*c_void;
    pub const getUserData = wl_global_get_user_data;

    // TODO: should we expose this making the signature of create unsafe?
    extern fn wl_global_set_user_data(global: *Global, data: ?*c_void) void;
};

pub const Resource = opaque {
    extern fn wl_resource_create(client: *Client, interface: *const common.Interface, version: c_int, id: u32) ?*Resource;
    pub fn create(client: *Client, comptime Object: type, version: u32, id: u32) !*Resource {
        // This is only a c_int because of legacy libwayland reasons. Negative versions are invalid.
        // Version is a u32 on the wire and for wl_global, wl_proxy, etc.
        return wl_resource_create(client, Object.interface, @intCast(c_int, version), id) orelse error.ResourceCreateFailed;
    }

    extern fn wl_resource_destroy(resource: *Resource) void;
    pub const destroy = wl_resource_destroy;

    extern fn wl_resource_post_event_array(resource: *Resource, opcode: u32, args: [*]common.Argument) void;
    pub const postEvent = wl_resource_post_event_array;

    extern fn wl_resource_queue_event_array(resource: *Resource, opcode: u32, args: [*]common.Argument) void;
    pub const queueEvent = wl_resource_queue_event_array;

    extern fn wl_resource_post_error(resource: *Resource, code: u32, message: [*:0]const u8, ...) void;
    pub const postError = wl_resource_post_error;

    extern fn wl_resource_post_no_memory(resource: *Resource) void;
    pub const postNoMemory = wl_resource_post_no_memory;

    const DispatcherFn = fn (
        implementation: ?*const c_void,
        resource: *Resource,
        opcode: u32,
        message: *const common.Message,
        args: [*]common.Argument,
    ) callconv(.C) c_int;
    pub const DestroyFn = fn (resource: *Resource) callconv(.C) void;
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
    ) void {
        wl_resource_set_dispatcher(resource, dispatcher, implementation, data, destroy);
    }

    extern fn wl_resource_get_user_data(resource: *Resource) ?*c_void;
    pub const getUserData = wl_resource_get_user_data;

    // TODO: should we expose this and lose type safety of the setDispatcher API?
    extern fn wl_resource_set_user_data(resource: *Resource, data: ?*c_void) void;

    extern fn wl_resource_get_id(resource: *Resource) u32;
    pub const getId = wl_resource_get_id;

    extern fn wl_resource_get_link(resource: *Resource) *List;
    pub const getLink = wl_resource_get_link;

    extern fn wl_resource_from_link(link: *List) *Resource;
    pub const fromLink = wl_resource_from_link;

    extern fn wl_resource_find_for_client(list: *List, client: *Client) ?*Resource;
    pub const findForClient = wl_resource_find_for_client;

    extern fn wl_resource_get_client(resource: *Resource) *Client;
    pub const getClient = wl_resource_get_client;

    extern fn wl_resource_get_version(resource: *Resource) c_int;
    pub fn getVersion(resource: *Resource) u32 {
        // The fact that wl_resource.version is a int in libwayland is
        // a mistake. Negative versions are impossible and u32 is used
        // everywhere else in libwayland
        return @intCast(u32, wl_resource_get_version(resource));
    }

    extern fn wl_resource_set_destructor(resource: *Resource, destroy: DestroyFn) void;
    pub const setDestructor = wl_resource_set_destructor;

    extern fn wl_resource_get_class(resource: *Resource) [*:0]const u8;
    pub const getClass = wl_resource_get_class;

    extern fn wl_resource_add_destroy_listener(resource: *Resource, listener: *Listener) void;
    pub const addDestroyListener = wl_resource_add_destroy_listener;

    extern fn wl_resource_get_destroy_listener(resource: *Resource, notify: Listener.NotifyFn) ?*Listener;
    pub const getDestroyListener = wl_resource_get_destroy_listener;
};

pub const ProtocolLogger = opaque {
    pub const Type = extern enum {
        request,
        event,
    };

    pub const Message = extern struct {
        resource: *Resource,
        message_opcode: c_int,
        message: *common.Message,
        arguments_count: c_int,
        arguments: ?[*]common.Argument,
    };

    extern fn wl_protocol_logger_destroy(logger: *ProtocolLogger) void;
    pub const destroy = wl_protocol_logger_destroy;
};

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
    pub fn create() *EventLoop {
        return wl_event_loop_create() orelse error.EventLoopCreateFailed;
    }

    extern fn wl_event_loop_destroy(loop: *EventLoop) void;
    pub const destroy = wl_event_loop_destroy;

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
    pub const dispatchIdle = wl_event_loop_dispatch_idle;

    extern fn wl_event_loop_get_fd(loop: *EventLoop) os.fd_t;
    pub const getFd = wl_event_loop_get_fd;

    extern fn wl_event_loop_add_destroy_listener(loop: *EventLoop, listener: *Listener) void;
    pub const addDestroyListener = wl_event_loop_add_destroy_listener;

    extern fn wl_event_loop_get_destroy_listener(loop: *EventLoop, notify: Listener.NotifyFn) ?*Listener;
    pub const getDestroyListener = wl_event_loop_get_destroy_listener;
};

pub const EventSource = opaque {
    extern fn wl_event_source_remove(source: *EventSource) c_int;
    pub fn remove(source: *EventSource) void {
        if (wl_event_source_remove(source) != 0) unreachable;
    }

    extern fn wl_event_source_check(source: *EventSource) void;
    pub const check = wl_event_source_check;

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

pub const shm = struct {
    pub const Buffer = opaque {
        extern fn wl_shm_buffer_get(resource: *Resource) ?*Buffer;
        pub const get = wl_shm_buffer_get;

        extern fn wl_shm_buffer_begin_access(buffer: *Buffer) void;
        pub const beginAccess = wl_shm_buffer_begin_access;

        extern fn wl_shm_buffer_end_access(buffer: *Buffer) void;
        pub const endAccess = wl_shm_buffer_end_access;

        extern fn wl_shm_buffer_get_data(buffer: *Buffer) ?*c_void;
        pub const getData = wl_shm_buffer_get_data;

        extern fn wl_shm_buffer_get_format(buffer: *Buffer) u32;
        pub const getFormat = wl_shm_buffer_get_format;

        extern fn wl_shm_buffer_get_height(buffer: *Buffer) i32;
        pub const getHeight = wl_shm_buffer_get_height;

        extern fn wl_shm_buffer_get_width(buffer: *Buffer) i32;
        pub const getWidth = wl_shm_buffer_get_width;

        extern fn wl_shm_buffer_get_stride(buffer: *Buffer) i32;
        pub const getStride = wl_shm_buffer_get_stride;

        extern fn wl_shm_buffer_ref_pool(buffer: *Buffer) *Pool;
        pub const refPool = wl_shm_buffer_ref_pool;
    };

    pub const Pool = opaque {
        extern fn wl_shm_pool_unref(pool: *Pool) void;
        pub const unref = wl_shm_pool_unref;
    };
};
