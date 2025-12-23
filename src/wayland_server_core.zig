pub const Object = common.Object;
pub const Message = common.Message;
pub const Interface = common.Interface;
pub const list = common.list;
pub const Array = common.Array;
pub const Fixed = common.Fixed;
pub const Argument = common.Argument;

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
    pub fn addSocket(_server: *Server, name: [*:0]const u8) !void {
        if (wl_display_add_socket(_server, name) == -1)
            return error.AddSocketFailed;
    }

    // wayland-client will connect to wayland-0 even if WAYLAND_DISPLAY is
    // unset due to an unfortunate piece of code that was not removed before
    // the library was stabilized. Because of this, it is a good idea to never
    // call the socket wayland-0. So, instead of binding to wayland-server's
    // wl_display_add_socket_auto we implement a version which skips wayland-0.
    pub fn addSocketAuto(_server: *Server, buf: *[11]u8) ![:0]const u8 {
        // Don't use wayland-0
        var i: u32 = 1;
        while (i <= 32) : (i += 1) {
            const name = std.fmt.bufPrintZ(buf, "wayland-{}", .{i}) catch unreachable;
            _server.addSocket(name.ptr) catch continue;
            return name;
        }
        return error.AddSocketFailed;
    }

    extern fn wl_display_add_socket_fd(_server: *Server, sock_fd: c_int) c_int;
    pub fn addSocketFd(_server: *Server, sock_fd: c_int) !void {
        if (wl_display_add_socket_fd(_server, sock_fd) == -1)
            return error.AddSocketFailed;
    }

    extern fn wl_display_terminate(_server: *Server) void;
    pub const terminate = wl_display_terminate;

    extern fn wl_display_run(_server: *Server) void;
    pub const run = wl_display_run;

    extern fn wl_display_flush_clients(_server: *Server) void;
    pub const flushClients = wl_display_flush_clients;

    extern fn wl_display_destroy_clients(_server: *Server) void;
    pub const destroyClients = wl_display_destroy_clients;

    extern fn wl_display_get_serial(_server: *Server) u32;
    pub const getSerial = wl_display_get_serial;

    extern fn wl_display_next_serial(_server: *Server) u32;
    pub const nextSerial = wl_display_next_serial;

    extern fn wl_display_add_destroy_listener(_server: *Server, listener: *Listener(*Server)) void;
    pub const addDestroyListener = wl_display_add_destroy_listener;

    extern fn wl_display_add_client_created_listener(_server: *Server, listener: *Listener(*Client)) void;
    pub const addClientCreatedListener = wl_display_add_client_created_listener;

    // Doesn't really make sense with our Listener API as we would need to
    // pass a pointer to the wrapper function
    //extern fn wl_display_get_destroy_listener(_server: *Server, notify: @TypeOf(Listener(*Server).notify)) ?*Listener(*Server);

    extern fn wl_display_set_global_filter(
        _server: *Server,
        filter: *const fn (_client: *const Client, global: *const Global, data: ?*anyopaque) callconv(.c) bool,
        data: ?*anyopaque,
    ) void;
    pub inline fn setGlobalFilter(
        _server: *Server,
        comptime T: type,
        comptime filter: fn (_client: *const Client, global: *const Global, data: T) bool,
        data: T,
    ) void {
        wl_display_set_global_filter(
            _server,
            struct {
                fn _wrapper(_client: *const Client, _global: *const Global, _data: ?*anyopaque) callconv(.c) bool {
                    return filter(_client, _global, @ptrCast(@alignCast(_data)));
                }
            }._wrapper,
            data,
        );
    }

    extern fn wl_display_get_client_list(_server: *Server) *list.Head(Client, null);
    pub const getClientList = wl_display_get_client_list;

    extern fn wl_display_init_shm(_server: *Server) c_int;
    pub fn initShm(_server: *Server) !void {
        if (wl_display_init_shm(_server) == -1) return error.OutOfMemory;
    }

    extern fn wl_display_add_shm_format(_server: *Server, format: u32) ?*u32;
    pub fn addShmFormat(_server: *Server, format: u32) !*u32 {
        return wl_display_add_shm_format(_server, format) orelse error.OutOfMemory;
    }

    extern fn wl_display_add_protocol_logger(
        _server: *Server,
        func: *const fn (data: ?*anyopaque, direction: ProtocolLogger.Type, message: *const ProtocolLogger.LogMessage) callconv(.c) void,
        data: ?*anyopaque,
    ) void;
    pub inline fn addProtocolLogger(
        _server: *Server,
        comptime T: type,
        comptime func: fn (data: T, direction: ProtocolLogger.Type, message: *const ProtocolLogger.LogMessage) void,
        data: T,
    ) void {
        wl_display_add_protocol_logger(
            _server,
            struct {
                fn _wrapper(_data: ?*anyopaque, _direction: ProtocolLogger.Type, _message: *const ProtocolLogger.LogMessage) callconv(.c) void {
                    func(@ptrCast(@alignCast(_data)), _direction, _message);
                }
            }._wrapper,
            data,
        );
    }
};

pub const Client = opaque {
    extern fn wl_client_create(_server: *Server, fd: c_int) ?*Client;
    pub const create = wl_client_create;

    extern fn wl_client_destroy(_client: *Client) void;
    pub const destroy = wl_client_destroy;

    extern fn wl_client_flush(_client: *Client) void;
    pub const flush = wl_client_flush;

    extern fn wl_client_get_link(_client: *Client) *list.Link;
    pub const getLink = wl_client_get_link;

    extern fn wl_client_from_link(link: *list.Link) *Client;
    pub const fromLink = wl_client_from_link;

    const Credentials = struct {
        pid: posix.pid_t,
        gid: posix.gid_t,
        uid: posix.uid_t,
    };
    extern fn wl_client_get_credentials(_client: *Client, pid: *posix.pid_t, uid: *posix.uid_t, gid: *posix.gid_t) void;
    pub fn getCredentials(_client: *Client) Credentials {
        var credentials: Credentials = undefined;
        wl_client_get_credentials(_client, &credentials.pid, &credentials.uid, &credentials.gid);
        return credentials;
    }

    extern fn wl_client_add_destroy_listener(_client: *Client, listener: *Listener(*Client)) void;
    pub const addDestroyListener = wl_client_add_destroy_listener;

    // Doesn't really make sense with our Listener API as we would need to
    // pass a pointer to the wrapper function
    //extern fn wl_client_get_destroy_listener(_client: *Client, notify: @TypeOf(Listener(*Client).notify)) ?*Listener(*Client);

    extern fn wl_client_get_object(_client: *Client, id: u32) ?*Resource;
    pub const getObject = wl_client_get_object;

    extern fn wl_client_post_no_memory(_client: *Client) void;
    pub const postNoMemory = wl_client_post_no_memory;

    extern fn wl_client_post_implementation_error(_client: *Client, msg: [*:0]const u8, ...) void;
    pub const postImplementationError = wl_client_post_implementation_error;

    extern fn wl_client_add_resource_created_listener(_client: *Client, listener: *Listener(*Resource)) void;
    pub const addResourceCreatedListener = wl_client_add_resource_created_listener;

    const IteratorResult = enum(c_int) { stop, cont };
    extern fn wl_client_for_each_resource(
        _client: *Client,
        iterator: *const fn (resource: *Resource, data: ?*anyopaque) callconv(.c) IteratorResult,
        data: ?*anyopaque,
    ) void;
    pub inline fn forEachResource(
        _client: *Client,
        comptime T: type,
        comptime iterator: fn (resource: *Resource, data: T) IteratorResult,
        data: T,
    ) void {
        wl_client_for_each_resource(
            _client,
            struct {
                fn _wrapper(_resource: *Resource, _data: ?*anyopaque) callconv(.c) IteratorResult {
                    return iterator(_resource, @ptrCast(@alignCast(_data)));
                }
            }._wrapper,
            data,
        );
    }

    extern fn wl_client_get_fd(_client: *Client) c_int;
    pub const getFd = wl_client_get_fd;

    extern fn wl_client_get_display(_client: *Client) *Server;
    pub const getDisplay = wl_client_get_display;
};

pub const Global = opaque {
    extern fn wl_global_create(
        _server: *Server,
        interface: *const Interface,
        version: c_int,
        data: ?*anyopaque,
        bind: *const fn (_client: *Client, data: ?*anyopaque, version: u32, id: u32) callconv(.c) void,
    ) ?*Global;
    pub inline fn create(
        _server: *Server,
        comptime T: type,
        version: u32,
        comptime DataT: type,
        data: DataT,
        comptime bind: fn (_client: *Client, data: DataT, version: u32, id: u32) void,
    ) error{GlobalCreateFailed}!*Global {
        return wl_global_create(
            _server,
            T.interface,
            @as(c_int, @intCast(version)),
            data,
            struct {
                fn _wrapper(_client: *Client, _data: ?*anyopaque, _version: u32, _id: u32) callconv(.c) void {
                    bind(_client, @ptrCast(@alignCast(_data)), _version, _id);
                }
            }._wrapper,
        ) orelse error.GlobalCreateFailed;
    }

    extern fn wl_global_remove(global: *Global) void;
    pub const remove = wl_global_remove;

    extern fn wl_global_destroy(global: *Global) void;
    pub const destroy = wl_global_destroy;

    extern fn wl_global_get_interface(global: *const Global) *const Interface;
    pub const getInterface = wl_global_get_interface;

    extern fn wl_global_get_name(global: *const Global, _client: *const Client) u32;
    pub const getName = wl_global_get_name;

    extern fn wl_global_get_user_data(global: *const Global) ?*anyopaque;
    pub const getUserData = wl_global_get_user_data;
};

pub const Resource = opaque {
    extern fn wl_resource_create(_client: *Client, interface: *const Interface, version: c_int, id: u32) ?*Resource;
    pub inline fn create(_client: *Client, comptime T: type, version: u32, id: u32) error{ResourceCreateFailed}!*Resource {
        // This is only a c_int because of legacy libwayland reasons. Negative versions are invalid.
        // Version is a u32 on the wire and for wl_global, wl_proxy, etc.
        return wl_resource_create(_client, T.interface, @as(c_int, @intCast(version)), id) orelse error.ResourceCreateFailed;
    }

    extern fn wl_resource_destroy(resource: *Resource) void;
    pub const destroy = wl_resource_destroy;

    extern fn wl_resource_post_event_array(resource: *Resource, opcode: u32, args: ?[*]Argument) void;
    pub const postEvent = wl_resource_post_event_array;

    extern fn wl_resource_queue_event_array(resource: *Resource, opcode: u32, args: ?[*]Argument) void;
    pub const queueEvent = wl_resource_queue_event_array;

    extern fn wl_resource_post_error(resource: *Resource, code: u32, message: [*:0]const u8, ...) void;
    pub const postError = wl_resource_post_error;

    extern fn wl_resource_post_no_memory(resource: *Resource) void;
    pub const postNoMemory = wl_resource_post_no_memory;

    const DispatcherFn = fn (
        implementation: ?*const anyopaque,
        resource: *Resource,
        opcode: u32,
        message: *const Message,
        args: [*]Argument,
    ) callconv(.c) c_int;
    pub const DestroyFn = fn (resource: *Resource) callconv(.c) void;
    extern fn wl_resource_set_dispatcher(
        resource: *Resource,
        dispatcher: ?*const DispatcherFn,
        implementation: ?*const anyopaque,
        data: ?*anyopaque,
        destroy_fn: ?*const DestroyFn,
    ) void;
    pub fn setDispatcher(
        resource: *Resource,
        dispatcher: ?*const DispatcherFn,
        implementation: ?*const anyopaque,
        data: ?*anyopaque,
        destroy_fn: ?*const DestroyFn,
    ) void {
        wl_resource_set_dispatcher(resource, dispatcher, implementation, data, destroy_fn);
    }

    extern fn wl_resource_get_user_data(resource: *Resource) ?*anyopaque;
    pub const getUserData = wl_resource_get_user_data;

    extern fn wl_resource_get_id(resource: *Resource) u32;
    pub const getId = wl_resource_get_id;

    extern fn wl_resource_get_link(resource: *Resource) *list.Link;
    pub const getLink = wl_resource_get_link;

    extern fn wl_resource_from_link(link: *list.Link) *Resource;
    pub const fromLink = wl_resource_from_link;

    extern fn wl_resource_find_for_client(list: *list.Head(Resource, null), _client: *Client) ?*Resource;
    pub const findForClient = wl_resource_find_for_client;

    extern fn wl_resource_get_client(resource: *Resource) *Client;
    pub const getClient = wl_resource_get_client;

    extern fn wl_resource_get_version(resource: *Resource) c_int;
    pub fn getVersion(resource: *Resource) u32 {
        // The fact that wl_resource.version is a int in libwayland is
        // a mistake. Negative versions are impossible and u32 is used
        // everywhere else in libwayland
        return @as(u32, @intCast(wl_resource_get_version(resource)));
    }

    // TOOD: unsure if this should be bound
    extern fn wl_resource_set_destructor(resource: *Resource, destroy: DestroyFn) void;

    extern fn wl_resource_get_class(resource: *Resource) [*:0]const u8;
    pub const getClass = wl_resource_get_class;

    extern fn wl_resource_add_destroy_listener(resource: *Resource, listener: *Listener(*Resource)) void;
    pub const addDestroyListener = wl_resource_add_destroy_listener;

    // Doesn't really make sense with our Listener API as we would need to
    // pass a pointer to the wrapper function
    //extern fn wl_resource_get_destroy_listener(resource: *Resource, notify: @TypeOf(Listener(*Resource).notify)) ?*Listener(*Resource);
};

pub const ProtocolLogger = opaque {
    pub const Type = enum(c_int) {
        request,
        event,
    };

    pub const LogMessage = extern struct {
        resource: *Resource,
        message_opcode: c_int,
        message: *Message,
        arguments_count: c_int,
        arguments: ?[*]Argument,
    };

    extern fn wl_protocol_logger_destroy(logger: *ProtocolLogger) void;
    pub const destroy = wl_protocol_logger_destroy;
};

pub fn Listener(comptime T: type) type {
    return extern struct {
        const Self = @This();

        pub const NotifyFn = if (T == void)
            fn (listener: *Self) void
        else
            fn (listener: *Self, data: T) void;

        link: list.Link,
        notify: *const fn (listener: *Self, data: ?*anyopaque) callconv(.c) void,

        pub fn init(comptime notify: NotifyFn) Self {
            var self: Self = undefined;
            self.setNotify(notify);
            return self;
        }

        pub fn setNotify(self: *Self, comptime notify: NotifyFn) void {
            self.notify = if (T == void)
                struct {
                    fn wrapper(listener: *Self, _: ?*anyopaque) callconv(.c) void {
                        @call(.always_inline, notify, .{listener});
                    }
                }.wrapper
            else
                struct {
                    fn wrapper(listener: *Self, data: ?*anyopaque) callconv(.c) void {
                        @call(.always_inline, notify, .{ listener, @as(T, @ptrFromInt(@intFromPtr(data))) });
                    }
                }.wrapper;
        }
    };
}

pub fn Signal(comptime T: type) type {
    return extern struct {
        const Self = @This();

        listener_list: list.Head(Listener(T), .link),

        pub fn init(signal: *Self) void {
            signal.listener_list.init();
        }

        pub fn add(signal: *Self, listener: *Listener(T)) void {
            signal.listener_list.append(listener);
        }

        pub fn get(signal: *Self, notify: @TypeOf(Listener(T).notify)) ?*Listener(T) {
            var it = signal.listener_list.iterator(.forward);
            return while (it.next()) |listener| {
                if (listener.notify == notify) break listener;
            } else null;
        }

        pub const emit = if (T == void)
            struct {
                pub inline fn emit(signal: *Self) void {
                    emitInner(signal, null);
                }
            }.emit
        else
            struct {
                pub inline fn emit(signal: *Self, data: T) void {
                    emitInner(signal, data);
                }
            }.emit;

        /// This is similar to wlroots' wlr_signal_emit_safe. It handles
        /// removal of any element in the list during iteration and stops at
        /// whatever the last element was when iteration started.
        fn emitInner(signal: *Self, data: ?*anyopaque) void {
            var cursor: Listener(T) = undefined;
            signal.listener_list.prepend(&cursor);

            var end: Listener(T) = undefined;
            signal.listener_list.append(&end);

            while (cursor.link.next != &end.link) {
                const pos = cursor.link.next.?;
                const listener: *Listener(T) = @fieldParentPtr("link", pos);

                cursor.link.remove();
                pos.insert(&cursor.link);

                listener.notify(listener, data);
            }

            cursor.link.remove();
            end.link.remove();
        }
    };
}

pub const EventMask = packed struct(u32) {
    readable: bool = false,
    writable: bool = false,
    hangup: bool = false,
    @"error": bool = false,

    _: u28 = 0,
};

pub const EventLoop = opaque {
    extern fn wl_event_loop_create() ?*EventLoop;
    pub fn create() !*EventLoop {
        return wl_event_loop_create() orelse error.EventLoopCreateFailed;
    }

    extern fn wl_event_loop_destroy(loop: *EventLoop) void;
    pub const destroy = wl_event_loop_destroy;

    extern fn wl_event_loop_add_fd(
        loop: *EventLoop,
        fd: c_int,
        mask: u32,
        func: *const fn (fd: c_int, mask: u32, data: ?*anyopaque) callconv(.c) c_int,
        data: ?*anyopaque,
    ) ?*EventSource;
    pub inline fn addFd(
        loop: *EventLoop,
        comptime T: type,
        fd: c_int,
        mask: EventMask,
        comptime func: fn (fd: c_int, mask: EventMask, data: T) c_int,
        data: T,
    ) error{AddFdFailed}!*EventSource {
        return wl_event_loop_add_fd(
            loop,
            fd,
            @bitCast(mask),
            struct {
                fn _wrapper(_fd: c_int, _mask: u32, _data: ?*anyopaque) callconv(.c) c_int {
                    return func(_fd, @bitCast(_mask), @ptrCast(@alignCast(_data)));
                }
            }._wrapper,
            data,
        ) orelse error.AddFdFailed;
    }

    extern fn wl_event_loop_add_timer(
        loop: *EventLoop,
        func: *const fn (data: ?*anyopaque) callconv(.c) c_int,
        data: ?*anyopaque,
    ) ?*EventSource;
    pub inline fn addTimer(
        loop: *EventLoop,
        comptime T: type,
        comptime func: fn (data: T) c_int,
        data: T,
    ) error{AddTimerFailed}!*EventSource {
        return wl_event_loop_add_timer(
            loop,
            struct {
                fn _wrapper(_data: ?*anyopaque) callconv(.c) c_int {
                    return func(@ptrCast(@alignCast(_data)));
                }
            }._wrapper,
            data,
        ) orelse error.AddTimerFailed;
    }

    extern fn wl_event_loop_add_signal(
        loop: *EventLoop,
        signal_number: c_int,
        func: *const fn (c_int, ?*anyopaque) callconv(.c) c_int,
        data: ?*anyopaque,
    ) ?*EventSource;
    pub inline fn addSignal(
        loop: *EventLoop,
        comptime T: type,
        signal_number: c_int,
        comptime func: fn (signal_number: c_int, data: T) c_int,
        data: T,
    ) error{AddSignalFailed}!*EventSource {
        return wl_event_loop_add_signal(
            loop,
            signal_number,
            struct {
                fn _wrapper(_signal_number: c_int, _data: ?*anyopaque) callconv(.c) c_int {
                    return func(_signal_number, @ptrCast(@alignCast(_data)));
                }
            }._wrapper,
            data,
        ) orelse error.AddSignalFailed;
    }

    extern fn wl_event_loop_add_idle(
        loop: *EventLoop,
        func: *const fn (data: ?*anyopaque) callconv(.c) void,
        data: ?*anyopaque,
    ) ?*EventSource;
    pub inline fn addIdle(
        loop: *EventLoop,
        comptime T: type,
        comptime func: fn (data: T) void,
        data: T,
    ) error{OutOfMemory}!*EventSource {
        return wl_event_loop_add_idle(
            loop,
            struct {
                fn _wrapper(_data: ?*anyopaque) callconv(.c) void {
                    return func(@ptrCast(@alignCast(_data)));
                }
            }._wrapper,
            data,
        ) orelse error.OutOfMemory;
    }

    extern fn wl_event_loop_dispatch(loop: *EventLoop, timeout: c_int) c_int;
    pub fn dispatch(loop: *EventLoop, timeout: c_int) !void {
        const rc = wl_event_loop_dispatch(loop, timeout);
        switch (posix.errno(rc)) {
            .SUCCESS => return,
            // TODO
            else => |err| return posix.unexpectedErrno(err),
        }
    }

    extern fn wl_event_loop_dispatch_idle(loop: *EventLoop) void;
    pub const dispatchIdle = wl_event_loop_dispatch_idle;

    extern fn wl_event_loop_get_fd(loop: *EventLoop) c_int;
    pub const getFd = wl_event_loop_get_fd;

    extern fn wl_event_loop_add_destroy_listener(loop: *EventLoop, listener: *Listener(*EventLoop)) void;
    pub const addDestroyListener = wl_event_loop_add_destroy_listener;

    //extern fn wl_event_loop_get_destroy_listener(loop: *EventLoop, notify: @TypeOf(Listener(*EventLoop).notify)) ?*Listener;
    //pub const getDestroyListener = wl_event_loop_get_destroy_listener;
};

pub const EventSource = opaque {
    extern fn wl_event_source_remove(source: *EventSource) c_int;
    pub fn remove(source: *EventSource) void {
        if (wl_event_source_remove(source) != 0) unreachable;
    }

    extern fn wl_event_source_check(source: *EventSource) void;
    pub const check = wl_event_source_check;

    extern fn wl_event_source_fd_update(source: *EventSource, mask: u32) c_int;
    pub fn fdUpdate(source: *EventSource, mask: EventMask) !void {
        const rc = wl_event_source_fd_update(source, @bitCast(mask));
        switch (posix.errno(rc)) {
            .SUCCESS => return,
            // TODO
            else => |err| return posix.unexpectedErrno(err),
        }
    }

    extern fn wl_event_source_timer_update(source: *EventSource, ms_delay: c_int) c_int;
    pub fn timerUpdate(source: *EventSource, ms_delay: c_int) !void {
        const rc = wl_event_source_timer_update(source, ms_delay);
        switch (posix.errno(rc)) {
            .SUCCESS => return,
            // TODO
            else => |err| return posix.unexpectedErrno(err),
        }
    }
};

pub const shm = struct {
    pub const Buffer = opaque {
        extern fn wl_shm_buffer_get(resource: *Resource) ?*shm.Buffer;
        pub const get = wl_shm_buffer_get;

        extern fn wl_shm_buffer_begin_access(buffer: *shm.Buffer) void;
        pub const beginAccess = wl_shm_buffer_begin_access;

        extern fn wl_shm_buffer_end_access(buffer: *shm.Buffer) void;
        pub const endAccess = wl_shm_buffer_end_access;

        extern fn wl_shm_buffer_get_data(buffer: *shm.Buffer) ?*anyopaque;
        pub const getData = wl_shm_buffer_get_data;

        extern fn wl_shm_buffer_get_format(buffer: *shm.Buffer) u32;
        pub const getFormat = wl_shm_buffer_get_format;

        extern fn wl_shm_buffer_get_height(buffer: *shm.Buffer) i32;
        pub const getHeight = wl_shm_buffer_get_height;

        extern fn wl_shm_buffer_get_width(buffer: *shm.Buffer) i32;
        pub const getWidth = wl_shm_buffer_get_width;

        extern fn wl_shm_buffer_get_stride(buffer: *shm.Buffer) i32;
        pub const getStride = wl_shm_buffer_get_stride;

        extern fn wl_shm_buffer_ref_pool(buffer: *shm.Buffer) *Pool;
        pub const refPool = wl_shm_buffer_ref_pool;
    };

    pub const Pool = opaque {
        extern fn wl_shm_pool_unref(pool: *Pool) void;
        pub const unref = wl_shm_pool_unref;
    };
};
