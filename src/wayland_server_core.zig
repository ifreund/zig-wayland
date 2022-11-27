const std = @import("std");
const os = std.os;

const common = @import("common.zig");
pub const Object = common.Object;
pub const Message = common.Message;
pub const Interface = common.Interface;
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
    pub fn addSocket(server: *Server, name: [*:0]const u8) !void {
        if (wl_display_add_socket(server, name) == -1)
            return error.AddSocketFailed;
    }

    // wayland-client will connect to wayland-0 even if WAYLAND_DISPLAY is
    // unset due to an unfortunate piece of code that was not removed before
    // the library was stabilized. Because of this, it is a good idea to never
    // call the socket wayland-0. So, instead of binding to wayland-server's
    // wl_display_add_socket_auto we implement a version which skips wayland-0.
    pub fn addSocketAuto(server: *Server, buf: *[11]u8) ![:0]const u8 {
        // Don't use wayland-0
        var i: u32 = 1;
        while (i <= 32) : (i += 1) {
            const name = std.fmt.bufPrintZ(buf, "wayland-{}", .{i}) catch unreachable;
            server.addSocket(name.ptr) catch continue;
            return name;
        }
        return error.AddSocketFailed;
    }

    extern fn wl_display_add_socket_fd(server: *Server, sock_fd: c_int) c_int;
    pub fn addSocketFd(server: *Server, sock_fd: c_int) !void {
        if (wl_display_add_socket_fd(server, sock_fd) == -1)
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

    extern fn wl_display_add_destroy_listener(server: *Server, listener: *Listener(*Server)) void;
    pub const addDestroyListener = wl_display_add_destroy_listener;

    extern fn wl_display_add_client_created_listener(server: *Server, listener: *Listener(*Client)) void;
    pub const addClientCreatedListener = wl_display_add_client_created_listener;

    // Doesn't really make sense with our Listener API as we would need to
    // pass a pointer to the wrapper function
    //extern fn wl_display_get_destroy_listener(server: *Server, notify: @TypeOf(Listener(*Server).notify)) ?*Listener(*Server);

    extern fn wl_display_set_global_filter(
        server: *Server,
        filter: *const fn (client: *const Client, global: *const Global, data: ?*anyopaque) callconv(.C) bool,
        data: ?*anyopaque,
    ) void;
    pub inline fn setGlobalFilter(
        server: *Server,
        comptime T: type,
        comptime filter: fn (client: *const Client, global: *const Global, data: T) bool,
        data: T,
    ) void {
        wl_display_set_global_filter(
            server,
            struct {
                fn wrapper(_client: *const Client, _global: *const Global, _data: ?*anyopaque) callconv(.C) bool {
                    filter(_client, _global, @ptrCast(T, @alignCast(@alignOf(T), _data)));
                }
            }._wrapper,
            data,
        );
    }

    extern fn wl_display_get_client_list(server: *Server) *list.Head(Client, null);
    pub const getClientList = wl_display_get_client_list;

    extern fn wl_display_init_shm(server: *Server) c_int;
    pub fn initShm(server: *Server) !void {
        if (wl_display_init_shm(server) == -1) return error.OutOfMemory;
    }

    extern fn wl_display_add_shm_format(server: *Server, format: u32) ?*u32;
    pub fn addShmFormat(server: *Server, format: u32) !*u32 {
        return wl_display_add_shm_format(server, format) orelse error.OutOfMemory;
    }

    extern fn wl_display_add_protocol_logger(
        server: *Server,
        func: *const fn (data: ?*anyopaque, direction: ProtocolLogger.Type, message: *const ProtocolLogger.LogMessage) callconv(.C) void,
        data: ?*anyopaque,
    ) void;
    pub inline fn addProtocolLogger(
        server: *Server,
        comptime T: type,
        comptime func: fn (data: T, direction: ProtocolLogger.Type, message: *const ProtocolLogger.LogMessage) void,
        data: T,
    ) void {
        wl_display_add_protocol_logger(
            server,
            struct {
                fn _wrapper(_data: ?*anyopaque, _direction: ProtocolLogger.Type, _message: *const ProtocolLogger.LogMessage) callconv(.C) void {
                    func(@ptrCast(T, @alignCast(@alignOf(T), _data)), _direction, _message);
                }
            },
            data,
        );
    }
};

pub const Client = opaque {
    extern fn wl_client_create(server: *Server, fd: c_int) ?*Client;
    pub const create = wl_client_create;

    extern fn wl_client_destroy(client: *Client) void;
    pub const destroy = wl_client_destroy;

    extern fn wl_client_flush(client: *Client) void;
    pub const flush = wl_client_flush;

    extern fn wl_client_get_link(client: *Client) *list.Link;
    pub const getLink = wl_client_get_link;

    extern fn wl_client_from_link(link: *list.Link) *Client;
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

    extern fn wl_client_add_destroy_listener(client: *Client, listener: *Listener(*Client)) void;
    pub const addDestroyListener = wl_client_add_destroy_listener;

    // Doesn't really make sense with our Listener API as we would need to
    // pass a pointer to the wrapper function
    //extern fn wl_client_get_destroy_listener(client: *Client, notify: @TypeOf(Listener(*Client).notify)) ?*Listener(*Client);

    extern fn wl_client_get_object(client: *Client, id: u32) ?*Resource;
    pub const getObject = wl_client_get_object;

    extern fn wl_client_post_no_memory(client: *Client) void;
    pub const postNoMemory = wl_client_post_no_memory;

    extern fn wl_client_post_implementation_error(client: *Client, msg: [*:0]const u8, ...) void;
    pub const postImplementationError = wl_client_post_implementation_error;

    extern fn wl_client_add_resource_created_listener(client: *Client, listener: *Listener(*Resource)) void;
    pub const addResourceCreatedListener = wl_client_add_resource_created_listener;

    const IteratorResult = enum(c_int) { stop, cont };
    extern fn wl_client_for_each_resource(
        client: *Client,
        iterator: *const fn (resource: *Resource, data: ?*anyopaque) callconv(.C) IteratorResult,
        data: ?*anyopaque,
    ) void;
    pub inline fn forEachResource(
        client: *Client,
        comptime T: type,
        comptime iterator: fn (resource: *Resource, data: T) IteratorResult,
        data: T,
    ) void {
        wl_client_for_each_resource(
            client,
            struct {
                fn _wrapper(_resource: *Resource, _data: ?*anyopaque) callconv(.C) IteratorResult {
                    return iterator(_resource, @ptrCast(T, @alignCast(@alignOf(T), _data)));
                }
            }._wrapper,
            data,
        );
    }

    extern fn wl_client_get_fd(client: *Client) c_int;
    pub const getFd = wl_client_get_fd;

    extern fn wl_client_get_display(client: *Client) *Server;
    pub const getDisplay = wl_client_get_display;
};

pub const Global = opaque {
    extern fn wl_global_create(
        server: *Server,
        interface: *const Interface,
        version: c_int,
        data: ?*anyopaque,
        bind: *const fn (client: *Client, data: ?*anyopaque, version: u32, id: u32) callconv(.C) void,
    ) ?*Global;
    pub inline fn create(
        server: *Server,
        comptime T: type,
        version: u32,
        comptime DataT: type,
        data: DataT,
        comptime bind: fn (client: *Client, data: DataT, version: u32, id: u32) void,
    ) error{GlobalCreateFailed}!*Global {
        return wl_global_create(
            server,
            T.getInterface(),
            @intCast(c_int, version),
            data,
            struct {
                fn _wrapper(_client: *Client, _data: ?*anyopaque, _version: u32, _id: u32) callconv(.C) void {
                    bind(_client, @ptrCast(DataT, @alignCast(@alignOf(DataT), _data)), _version, _id);
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

    extern fn wl_global_get_user_data(global: *const Global) ?*anyopaque;
    pub const getUserData = wl_global_get_user_data;
};

pub const Resource = opaque {
    extern fn wl_resource_create(client: *Client, interface: *const Interface, version: c_int, id: u32) ?*Resource;
    pub inline fn create(client: *Client, comptime T: type, version: u32, id: u32) error{ResourceCreateFailed}!*Resource {
        // This is only a c_int because of legacy libwayland reasons. Negative versions are invalid.
        // Version is a u32 on the wire and for wl_global, wl_proxy, etc.
        return wl_resource_create(client, T.getInterface(), @intCast(c_int, version), id) orelse error.ResourceCreateFailed;
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
    ) callconv(.C) c_int;
    pub const DestroyFn = fn (resource: *Resource) callconv(.C) void;
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

    extern fn wl_resource_find_for_client(list: *list.Head(Resource, null), client: *Client) ?*Resource;
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

pub const list = struct {
    pub const Link = extern struct {
        prev: ?*Link,
        next: ?*Link,

        pub fn insertAfter(link: *Link, other: *Link) void {
            other.prev = link;
            other.next = link.next;
            link.next = other;
            other.next.?.prev = other;
        }

        pub fn remove(link: *Link) void {
            link.prev.?.next = link.next;
            link.next.?.prev = link.prev;
            link.* = .{ .prev = null, .next = null };
        }
    };

    pub const Direction = enum {
        forward,
        reverse,
    };

    /// This has the same ABI as wl.list.Link/wl_list. If link_field is null, then
    /// T.getLink()/T.fromLink() will be used. This allows for compatiability
    /// with wl.Client and wl.Resource
    pub fn Head(comptime T: type, comptime link_field: ?[]const u8) type {
        return extern struct {
            const Self = @This();

            link: Link,

            pub fn init(head: *Self) void {
                head.* = .{ .link = .{ .prev = &head.link, .next = &head.link } };
            }

            pub fn prepend(head: *Self, elem: *T) void {
                const link = if (link_field) |f| &@field(elem, f) else elem.getLink();
                head.link.insertAfter(link);
            }

            pub fn append(head: *Self, elem: *T) void {
                const link = if (link_field) |f| &@field(elem, f) else elem.getLink();
                head.link.prev.?.insertAfter(link);
            }

            pub fn length(head: *const Self) usize {
                var count: usize = 0;
                var current = head.link.next.?;
                while (current != &head.link) : (current = current.next.?) {
                    count += 1;
                }
                return count;
            }

            pub fn empty(head: *const Self) bool {
                return head.link.next == &head.link;
            }

            pub fn insertList(head: *Self, other: *Self) void {
                if (other.empty()) return;
                other.link.next.?.prev = head.link;
                other.link.prev.?.next = head.link.next;
                head.link.next.?.prev = other.link.prev;
                head.link.next = other.link.next;
            }

            /// Removal of elements during iteration is illegal
            pub fn Iterator(comptime direction: Direction) type {
                return struct {
                    head: *Link,
                    current: *Link,

                    pub fn next(it: *@This()) ?*T {
                        it.current = switch (direction) {
                            .forward => it.current.next.?,
                            .reverse => it.current.prev.?,
                        };
                        if (it.current == it.head) return null;
                        return if (link_field) |f| @fieldParentPtr(T, f, it.current) else T.fromLink(it.current);
                    }
                };
            }

            /// Removal of elements during iteration is illegal
            pub fn iterator(head: *Self, comptime direction: Direction) Iterator(direction) {
                return .{ .head = &head.link, .current = &head.link };
            }

            /// Removal of the current element during iteration is permitted.
            /// Removal of other elements is illegal.
            pub fn SafeIterator(comptime direction: Direction) type {
                return struct {
                    head: *Link,
                    current: *Link,
                    future: *Link,

                    pub fn next(it: *@This()) ?*T {
                        it.current = it.future;
                        it.future = switch (direction) {
                            .forward => it.future.next.?,
                            .reverse => it.future.prev.?,
                        };
                        if (it.current == it.head) return null;
                        return if (link_field) |f| @fieldParentPtr(T, f, it.current) else T.fromLink(it.current);
                    }
                };
            }

            /// Removal of the current element during iteration is permitted.
            /// Removal of other elements is illegal.
            pub fn safeIterator(head: *Self, comptime direction: Direction) SafeIterator(direction) {
                return .{
                    .head = &head.link,
                    .current = &head.link,
                    .future = switch (direction) {
                        .forward => head.link.next.?,
                        .reverse => head.link.prev.?,
                    },
                };
            }
        };
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
        notify: *const fn (listener: *Self, data: ?*anyopaque) callconv(.C) void,

        pub fn init(comptime notify: NotifyFn) Self {
            var self: Self = undefined;
            self.setNotify(notify);
            return self;
        }

        pub fn setNotify(self: *Self, comptime notify: NotifyFn) void {
            self.notify = if (T == void)
                struct {
                    fn wrapper(listener: *Self, _: ?*anyopaque) callconv(.C) void {
                        @call(.{ .modifier = .always_inline }, notify, .{listener});
                    }
                }.wrapper
            else
                struct {
                    fn wrapper(listener: *Self, data: ?*anyopaque) callconv(.C) void {
                        @call(.{ .modifier = .always_inline }, notify, .{ listener, @intToPtr(T, @ptrToInt(data)) });
                    }
                }.wrapper;
        }
    };
}

pub fn Signal(comptime T: type) type {
    return extern struct {
        const Self = @This();

        listener_list: list.Head(Listener(T), "link"),

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
                const listener = @fieldParentPtr(Listener(T), "link", pos);

                cursor.link.remove();
                pos.insertAfter(&cursor.link);

                listener.notify(listener, data);
            }

            cursor.link.remove();
            end.link.remove();
        }
    };
}

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
        func: *const fn (fd: c_int, mask: u32, data: ?*anyopaque) callconv(.C) c_int,
        data: ?*anyopaque,
    ) ?*EventSource;
    pub inline fn addFd(
        loop: *EventLoop,
        comptime T: type,
        fd: c_int,
        mask: u32,
        comptime func: fn (fd: c_int, mask: u32, data: T) c_int,
        data: T,
    ) error{AddFdFailed}!*EventSource {
        return wl_event_loop_add_fd(
            loop,
            fd,
            mask,
            struct {
                fn _wrapper(_fd: c_int, _mask: u32, _data: ?*anyopaque) callconv(.C) c_int {
                    return func(_fd, _mask, @ptrCast(T, @alignCast(@alignOf(T), _data)));
                }
            }._wrapper,
            data,
        ) orelse error.AddFdFailed;
    }

    extern fn wl_event_loop_add_timer(
        loop: *EventLoop,
        func: *const fn (data: ?*anyopaque) callconv(.C) c_int,
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
                fn _wrapper(_data: ?*anyopaque) callconv(.C) c_int {
                    return func(@ptrCast(T, @alignCast(@alignOf(T), _data)));
                }
            }._wrapper,
            data,
        ) orelse error.AddTimerFailed;
    }

    extern fn wl_event_loop_add_signal(
        loop: *EventLoop,
        signal_number: c_int,
        func: *const fn (c_int, ?*anyopaque) callconv(.C) c_int,
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
                fn _wrapper(_signal_number: c_int, _data: ?*anyopaque) callconv(.C) c_int {
                    return func(_signal_number, @ptrCast(T, @alignCast(@alignOf(T), _data)));
                }
            }._wrapper,
            data,
        ) orelse error.AddSignalFailed;
    }

    extern fn wl_event_loop_add_idle(
        loop: *EventLoop,
        func: *const fn (data: ?*anyopaque) callconv(.C) void,
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
                fn _wrapper(_data: ?*anyopaque) callconv(.C) c_int {
                    return func(@ptrCast(T, @alignCast(@alignOf(T), _data)));
                }
            }._wrapper,
            data,
        ) orelse error.OutOfMemory;
    }

    extern fn wl_event_loop_dispatch(loop: *EventLoop, timeout: c_int) c_int;
    pub fn dispatch(loop: *EventLoop, timeout: c_int) !void {
        const rc = wl_event_loop_dispatch(loop, timeout);
        switch (os.errno(rc)) {
            .SUCCESS => return,
            // TODO
            else => |err| return os.unexpectedErrno(err),
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
    pub fn fdUpdate(source: *EventSource, mask: u32) !void {
        const rc = wl_event_source_fd_update(source, mask);
        switch (os.errno(rc)) {
            .SUCCESS => return,
            // TODO
            else => |err| return os.unexpectedErrno(err),
        }
    }

    extern fn wl_event_source_timer_update(source: *EventSource, ms_delay: c_int) c_int;
    pub fn timerUpdate(source: *EventSource, ms_delay: c_int) !void {
        const rc = wl_event_source_timer_update(source, ms_delay);
        switch (os.errno(rc)) {
            .SUCCESS => return,
            // TODO
            else => |err| return os.unexpectedErrno(err),
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

        extern fn wl_shm_buffer_get_data(buffer: *Buffer) ?*anyopaque;
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
