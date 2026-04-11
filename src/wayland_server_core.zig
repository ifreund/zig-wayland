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
    pub inline fn create() error{ServerCreateFailed}!*Server {
        return ffi.server.wl_display_create() orelse error.ServerCreateFailed;
    }

    pub inline fn destroy(_server: *Server) void {
        ffi.server.wl_display_destroy(_server);
    }

    pub inline fn getEventLoop(_server: *Server) *EventLoop {
        return ffi.server.wl_display_get_event_loop(_server);
    }

    pub inline fn addSocket(_server: *Server, name: [*:0]const u8) error{AddSocketFailed}!void {
        if (ffi.server.wl_display_add_socket(_server, name) == -1)
            return error.AddSocketFailed;
    }

    // wayland-client will connect to wayland-0 even if WAYLAND_DISPLAY is
    // unset due to an unfortunate piece of code that was not removed before
    // the library was stabilized. Because of this, it is a good idea to never
    // call the socket wayland-0. So, instead of binding to wayland-server's
    // wl_display_add_socket_auto we implement a version which skips wayland-0.
    pub fn addSocketAuto(_server: *Server, buf: *[11]u8) error{AddSocketFailed}![:0]const u8 {
        // Don't use wayland-0
        var i: u32 = 1;
        while (i <= 32) : (i += 1) {
            const name = std.fmt.bufPrintZ(buf, "wayland-{}", .{i}) catch unreachable;
            _server.addSocket(name.ptr) catch continue;
            return name;
        }
        return error.AddSocketFailed;
    }

    pub inline fn addSocketFd(_server: *Server, sock_fd: c_int) error{AddSocketFailed}!void {
        if (ffi.server.wl_display_add_socket_fd(_server, sock_fd) == -1)
            return error.AddSocketFailed;
    }

    pub inline fn terminate(_server: *Server) void {
        ffi.server.wl_display_terminate(_server);
    }

    pub inline fn run(_server: *Server) void {
        ffi.server.wl_display_run(_server);
    }

    pub inline fn flushClients(_server: *Server) void {
        ffi.server.wl_display_flush_clients(_server);
    }

    pub inline fn destroyClients(_server: *Server) void {
        ffi.server.wl_display_destroy_clients(_server);
    }

    pub inline fn getSerial(_server: *Server) u32 {
        return ffi.server.wl_display_get_serial(_server);
    }

    pub inline fn nextSerial(_server: *Server) u32 {
        return ffi.server.wl_display_next_serial(_server);
    }

    pub inline fn addDestroyListener(_server: *Server, listener: *Listener(*Server)) void {
        ffi.server.wl_display_add_destroy_listener(_server, listener);
    }

    pub inline fn addClientCreatedListener(_server: *Server, listener: *Listener(*Client)) void {
        ffi.server.wl_display_add_client_created_listener(_server, listener);
    }

    // Doesn't really make sense with our Listener API as we would need to
    // pass a pointer to the wrapper function
    //fn wl_display_get_destroy_listener(_server: *Server, notify: @TypeOf(Listener(*Server).notify)) ?*Listener(*Server);

    pub inline fn setGlobalFilter(
        _server: *Server,
        comptime T: type,
        comptime filter: fn (_client: *const Client, global: *const Global, data: T) bool,
        data: T,
    ) void {
        ffi.server.wl_display_set_global_filter(
            _server,
            struct {
                fn _wrapper(_client: *const Client, global: *const Global, _data: ?*anyopaque) callconv(.c) bool {
                    return filter(_client, global, @ptrCast(@alignCast(_data)));
                }
            }._wrapper,
            data,
        );
    }

    pub inline fn getClientList(_server: *Server) *list.Head(Client, null) {
        return ffi.server.wl_display_get_client_list(_server);
    }

    pub inline fn initShm(_server: *Server) error{OutOfMemory}!void {
        if (ffi.server.wl_display_init_shm(_server) == -1) return error.OutOfMemory;
    }

    pub inline fn addShmFormat(_server: *Server, format: u32) error{OutOfMemory}!*u32 {
        return ffi.server.wl_display_add_shm_format(_server, format) orelse error.OutOfMemory;
    }

    pub inline fn addProtocolLogger(
        _server: *Server,
        comptime T: type,
        comptime func: fn (data: T, direction: ProtocolLogger.Type, message: *const ProtocolLogger.LogMessage) void,
        data: T,
    ) void {
        ffi.server.wl_display_add_protocol_logger(
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
    pub inline fn create(_server: *Server, fd: c_int) ?*Client {
        return ffi.server.wl_client_create(_server, fd);
    }

    pub inline fn destroy(_client: *Client) void {
        ffi.server.wl_client_destroy(_client);
    }

    pub inline fn flush(_client: *Client) void {
        ffi.server.wl_client_flush(_client);
    }

    pub inline fn getLink(_client: *Client) *list.Link {
        return ffi.server.wl_client_get_link(_client);
    }

    pub inline fn fromLink(link: *list.Link) *Client {
        return ffi.server.wl_client_from_link(link);
    }

    pub const Credentials = struct {
        pid: posix.pid_t,
        gid: posix.gid_t,
        uid: posix.uid_t,
    };
    pub inline fn getCredentials(_client: *Client) Credentials {
        var credentials: Credentials = undefined;
        ffi.server.wl_client_get_credentials(_client, &credentials.pid, &credentials.uid, &credentials.gid);
        return credentials;
    }

    pub inline fn addDestroyListener(_client: *Client, listener: *Listener(*Client)) void {
        ffi.server.wl_client_add_destroy_listener(_client, listener);
    }

    // Doesn't really make sense with our Listener API as we would need to
    // pass a pointer to the wrapper function
    //fn wl_client_get_destroy_listener(_client: *Client, notify: @TypeOf(Listener(*Client).notify)) ?*Listener(*Client);

    pub inline fn getObject(_client: *Client, id: u32) ?*Resource {
        return ffi.server.wl_client_get_object(_client, id);
    }

    pub inline fn postNoMemory(_client: *Client) void {
        ffi.server.wl_client_post_no_memory(_client);
    }

    pub inline fn postImplementationError(_client: *Client, msg: [*:0]const u8) void {
        ffi.server.wl_client_post_implementation_error(_client, "%s", msg);
    }

    pub inline fn addResourceCreatedListener(_client: *Client, listener: *Listener(*Resource)) void {
        ffi.server.wl_client_add_resource_created_listener(_client, listener);
    }

    pub const IteratorResult = enum(c_int) { stop, cont };
    pub inline fn forEachResource(
        _client: *Client,
        comptime T: type,
        comptime iterator: fn (resource: *Resource, data: T) IteratorResult,
        data: T,
    ) void {
        ffi.server.wl_client_for_each_resource(
            _client,
            struct {
                fn _wrapper(_resource: *Resource, _data: ?*anyopaque) callconv(.c) IteratorResult {
                    return iterator(_resource, @ptrCast(@alignCast(_data)));
                }
            }._wrapper,
            data,
        );
    }

    pub inline fn getFd(_client: *Client) c_int {
        return ffi.server.wl_client_get_fd(_client);
    }

    pub inline fn getDisplay(_client: *Client) *Server {
        return ffi.server.wl_client_get_display(_client);
    }
};

pub const Global = opaque {
    pub inline fn create(
        _server: *Server,
        comptime T: type,
        version: u32,
        comptime DataT: type,
        data: DataT,
        comptime bind: fn (_client: *Client, data: DataT, version: u32, id: u32) void,
    ) error{GlobalCreateFailed}!*Global {
        return ffi.server.wl_global_create(
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

    pub inline fn remove(global: *Global) void {
        ffi.server.wl_global_remove(global);
    }

    pub inline fn destroy(global: *Global) void {
        ffi.server.wl_global_destroy(global);
    }

    pub inline fn getInterface(global: *const Global) *const Interface {
        return ffi.server.wl_global_get_interface(global);
    }

    pub inline fn getName(global: *const Global, _client: *const Client) u32 {
        return ffi.server.wl_global_get_name(global, _client);
    }

    pub inline fn getUserData(global: *const Global) ?*anyopaque {
        return ffi.server.wl_global_get_user_data(global);
    }
};

pub const Resource = opaque {
    pub inline fn create(_client: *Client, comptime T: type, version: u32, id: u32) error{ResourceCreateFailed}!*Resource {
        // This is only a c_int because of legacy libwayland reasons. Negative versions are invalid.
        // Version is a u32 on the wire and for wl_global, wl_proxy, etc.
        return ffi.server.wl_resource_create(_client, T.interface, @as(c_int, @intCast(version)), id) orelse error.ResourceCreateFailed;
    }

    pub inline fn destroy(resource: *Resource) void {
        ffi.server.wl_resource_destroy(resource);
    }

    pub inline fn postEvent(resource: *Resource, opcode: u32, args: ?[*]Argument) void {
        ffi.server.wl_resource_post_event_array(resource, opcode, args);
    }

    pub inline fn queueEvent(resource: *Resource, opcode: u32, args: ?[*]Argument) void {
        ffi.server.wl_resource_queue_event_array(resource, opcode, args);
    }

    pub inline fn postError(resource: *Resource, code: u32, message: [*:0]const u8) void {
        ffi.server.wl_resource_post_error(resource, code, "%s", message);
    }

    pub inline fn postNoMemory(resource: *Resource) void {
        ffi.server.wl_resource_post_no_memory(resource);
    }

    pub const DispatcherFn = fn (
        implementation: ?*const anyopaque,
        resource: *Resource,
        opcode: u32,
        message: *const Message,
        args: [*]Argument,
    ) callconv(.c) c_int;
    pub const DestroyFn = fn (resource: *Resource) callconv(.c) void;
    pub inline fn setDispatcher(
        resource: *Resource,
        dispatcher: ?*const DispatcherFn,
        implementation: ?*const anyopaque,
        data: ?*anyopaque,
        destroy_fn: ?*const DestroyFn,
    ) void {
        ffi.server.wl_resource_set_dispatcher(resource, dispatcher, implementation, data, destroy_fn);
    }

    pub inline fn getUserData(resource: *Resource) ?*anyopaque {
        return ffi.server.wl_resource_get_user_data(resource);
    }

    pub inline fn getId(resource: *Resource) u32 {
        return ffi.server.wl_resource_get_id(resource);
    }

    pub inline fn getLink(resource: *Resource) *list.Link {
        return ffi.server.wl_resource_get_link(resource);
    }

    pub inline fn fromLink(link: *list.Link) *Resource {
        return ffi.server.wl_resource_from_link(link);
    }

    pub inline fn findForClient(_list: *list.Head(Resource, null), _client: *Client) ?*Resource {
        return ffi.server.wl_resource_find_for_client(_list, _client);
    }

    pub inline fn getClient(resource: *Resource) *Client {
        return ffi.server.wl_resource_get_client(resource);
    }

    pub inline fn getVersion(resource: *Resource) u32 {
        // The fact that wl_resource.version is a int in libwayland is
        // a mistake. Negative versions are impossible and u32 is used
        // everywhere else in libwayland
        return @as(u32, @intCast(ffi.server.wl_resource_get_version(resource)));
    }

    // TOOD: unsure if this should be bound
    //fn wl_resource_set_destructor(resource: *Resource, destroy: DestroyFn) void;

    pub inline fn getClass(resource: *Resource) [*:0]const u8 {
        return ffi.server.wl_resource_get_class(resource);
    }

    pub inline fn addDestroyListener(resource: *Resource, listener: *Listener(*Resource)) void {
        ffi.server.wl_resource_add_destroy_listener(resource, listener);
    }

    // Doesn't really make sense with our Listener API as we would need to
    // pass a pointer to the wrapper function
    //fn wl_resource_get_destroy_listener(resource: *Resource, notify: @TypeOf(Listener(*Resource).notify)) ?*Listener(*Resource);
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

    pub inline fn destroy(logger: *ProtocolLogger) void {
        ffi.server.wl_protocol_logger_destroy(logger);
    }
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
                        notify(listener);
                    }
                }.wrapper
            else
                struct {
                    fn wrapper(listener: *Self, data: ?*anyopaque) callconv(.c) void {
                        notify(listener, @ptrFromInt(@intFromPtr(data)));
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
    pub inline fn create() error{EventLoopCreateFailed}!*EventLoop {
        return ffi.server.wl_event_loop_create() orelse error.EventLoopCreateFailed;
    }

    pub inline fn destroy(loop: *EventLoop) void {
        ffi.server.wl_event_loop_destroy(loop);
    }

    pub inline fn addFd(
        loop: *EventLoop,
        comptime T: type,
        fd: c_int,
        mask: EventMask,
        comptime func: fn (fd: c_int, mask: EventMask, data: T) c_int,
        data: T,
    ) error{AddFdFailed}!*EventSource {
        return ffi.server.wl_event_loop_add_fd(
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

    pub inline fn addTimer(
        loop: *EventLoop,
        comptime T: type,
        comptime func: fn (data: T) c_int,
        data: T,
    ) error{AddTimerFailed}!*EventSource {
        return ffi.server.wl_event_loop_add_timer(
            loop,
            struct {
                fn _wrapper(_data: ?*anyopaque) callconv(.c) c_int {
                    return func(@ptrCast(@alignCast(_data)));
                }
            }._wrapper,
            data,
        ) orelse error.AddTimerFailed;
    }

    pub inline fn addSignal(
        loop: *EventLoop,
        comptime T: type,
        signal_number: c_int,
        comptime func: fn (signal_number: c_int, data: T) c_int,
        data: T,
    ) error{AddSignalFailed}!*EventSource {
        return ffi.server.wl_event_loop_add_signal(
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

    pub inline fn addIdle(
        loop: *EventLoop,
        comptime T: type,
        comptime func: fn (data: T) void,
        data: T,
    ) error{OutOfMemory}!*EventSource {
        return ffi.server.wl_event_loop_add_idle(
            loop,
            struct {
                fn _wrapper(_data: ?*anyopaque) callconv(.c) void {
                    return func(@ptrCast(@alignCast(_data)));
                }
            }._wrapper,
            data,
        ) orelse error.OutOfMemory;
    }

    pub inline fn dispatch(loop: *EventLoop, timeout: c_int) posix.UnexpectedError!void {
        const rc = ffi.server.wl_event_loop_dispatch(loop, timeout);
        switch (posix.errno(rc)) {
            .SUCCESS => return,
            // TODO
            else => |err| return posix.unexpectedErrno(err),
        }
    }

    pub inline fn dispatchIdle(loop: *EventLoop) void {
        ffi.server.wl_event_loop_dispatch_idle(loop);
    }

    pub inline fn getFd(loop: *EventLoop) c_int {
        return ffi.server.wl_event_loop_get_fd(loop);
    }

    pub inline fn addDestroyListener(loop: *EventLoop, listener: *Listener(*EventLoop)) void {
        ffi.server.wl_event_loop_add_destroy_listener(loop, listener);
    }

    //fn wl_event_loop_get_destroy_listener(loop: *EventLoop, notify: @TypeOf(Listener(*EventLoop).notify)) ?*Listener;
    //pub const getDestroyListener = wl_event_loop_get_destroy_listener;
};

pub const EventSource = opaque {
    pub inline fn remove(source: *EventSource) void {
        if (ffi.server.wl_event_source_remove(source) != 0) unreachable;
    }

    pub inline fn check(source: *EventSource) void {
        ffi.server.wl_event_source_check(source);
    }

    pub inline fn fdUpdate(source: *EventSource, mask: EventMask) posix.UnexpectedError!void {
        const rc = ffi.server.wl_event_source_fd_update(source, @bitCast(mask));
        switch (posix.errno(rc)) {
            .SUCCESS => return,
            // TODO
            else => |err| return posix.unexpectedErrno(err),
        }
    }

    pub inline fn timerUpdate(source: *EventSource, ms_delay: c_int) posix.UnexpectedError!void {
        const rc = ffi.server.wl_event_source_timer_update(source, ms_delay);
        switch (posix.errno(rc)) {
            .SUCCESS => return,
            // TODO
            else => |err| return posix.unexpectedErrno(err),
        }
    }
};

pub const shm = struct {
    pub const Buffer = opaque {
        pub inline fn get(resource: *Resource) ?*shm.Buffer {
            return ffi.server.wl_shm_buffer_get(resource);
        }

        pub inline fn beginAccess(buffer: *shm.Buffer) void {
            ffi.server.wl_shm_buffer_begin_access(buffer);
        }

        pub inline fn endAccess(buffer: *shm.Buffer) void {
            ffi.server.wl_shm_buffer_end_access(buffer);
        }

        pub inline fn getData(buffer: *shm.Buffer) ?*anyopaque {
            return ffi.server.wl_shm_buffer_get_data(buffer);
        }

        pub inline fn getFormat(buffer: *shm.Buffer) u32 {
            return ffi.server.wl_shm_buffer_get_format(buffer);
        }

        pub inline fn getHeight(buffer: *shm.Buffer) i32 {
            return ffi.server.wl_shm_buffer_get_height(buffer);
        }

        pub inline fn getWidth(buffer: *shm.Buffer) i32 {
            return ffi.server.wl_shm_buffer_get_width(buffer);
        }

        pub inline fn getStride(buffer: *shm.Buffer) i32 {
            return ffi.server.wl_shm_buffer_get_stride(buffer);
        }

        pub inline fn refPool(buffer: *shm.Buffer) *Pool {
            return ffi.server.wl_shm_buffer_ref_pool(buffer);
        }
    };

    pub const Pool = opaque {
        pub inline fn unref(pool: *Pool) void {
            ffi.server.wl_shm_pool_unref(pool);
        }
    };
};
