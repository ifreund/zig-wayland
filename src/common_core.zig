const Object = opaque {};

const Message = extern struct {
    name: [*:0]const u8,
    signature: [*:0]const u8,
    types: ?[*]const ?*const Interface,
};

const Interface = extern struct {
    name: [*:0]const u8,
    version: c_int,
    method_count: c_int,
    methods: ?[*]const Message,
    event_count: c_int,
    events: ?[*]const Message,
};

const list = struct {
    pub const Link = extern struct {
        prev: ?*Link,
        next: ?*Link,

        pub fn init(link: *Link) void {
            link.* = .{ .prev = link, .next = link };
        }

        pub fn insert(link: *Link, other: *Link) void {
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

        pub fn replaceWith(link: *Link, other: *Link) void {
            other.next = link.next;
            other.next.?.prev = other;
            other.prev = link.prev;
            other.prev.?.next = other;

            link.* = .{ .prev = null, .next = null };
        }

        pub fn swapWith(link: *Link, other: *Link) void {
            const old_other_prev = other.prev.?;
            other.remove();

            link.replaceWith(other);

            if (old_other_prev == link) {
                other.insert(link);
            } else {
                old_other_prev.insert(link);
            }
        }

        /// private helper that doesn't handle empty lists and assumes that
        /// other is the link of a Head.
        fn insertList(link: *Link, other: *Link) void {
            other.next.?.prev = link;
            other.prev.?.next = link.next;
            link.next.?.prev = other.prev;
            link.next = other.next;

            other.init();
        }
    };

    pub const Direction = enum {
        forward,
        reverse,
    };

    /// This has the same ABI as wl.list.Link/wl_list. If link_field is null, then
    /// T.getLink()/T.fromLink() will be used. This allows for compatiability
    /// with wl.Client and wl.Resource
    pub fn Head(comptime T: type, comptime link_field: ?@Type(.enum_literal)) type {
        return extern struct {
            const Self = @This();

            link: Link,

            pub fn init(head: *Self) void {
                head.link.init();
            }

            pub fn prepend(head: *Self, elem: *T) void {
                head.link.insert(linkFromElem(elem));
            }

            pub fn append(head: *Self, elem: *T) void {
                head.link.prev.?.insert(linkFromElem(elem));
            }

            pub fn prependList(head: *Self, other: *Self) void {
                if (other.empty()) return;
                head.link.insertList(&other.link);
            }

            pub fn appendList(head: *Self, other: *Self) void {
                if (other.empty()) return;
                head.link.prev.?.insertList(&other.link);
            }

            pub fn first(head: *Self) ?*T {
                if (head.empty()) {
                    return null;
                } else {
                    return elemFromLink(head.link.next.?);
                }
            }

            pub fn last(head: *Self) ?*T {
                if (head.empty()) {
                    return null;
                } else {
                    return elemFromLink(head.link.prev.?);
                }
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

            /// Removal of the current element during iteration is permitted.
            /// Removal of other elements is illegal.
            pub fn Iterator(comptime direction: Direction) type {
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
                        return elemFromLink(it.current);
                    }
                };
            }

            /// Removal of the current element during iteration is permitted.
            /// Removal of other elements is illegal.
            pub fn iterator(head: *Self, comptime direction: Direction) Iterator(direction) {
                return .{
                    .head = &head.link,
                    .current = &head.link,
                    .future = switch (direction) {
                        .forward => head.link.next.?,
                        .reverse => head.link.prev.?,
                    },
                };
            }

            pub const safeIterator = iterator;
            pub const SafeIterator = Iterator;

            fn linkFromElem(elem: *T) *Link {
                if (link_field) |f| {
                    return &@field(elem, @tagName(f));
                } else {
                    return elem.getLink();
                }
            }

            fn elemFromLink(link: *Link) *T {
                if (link_field) |f| {
                    return @fieldParentPtr(@tagName(f), link);
                } else {
                    return T.fromLink(link);
                }
            }
        };
    }
};

const Array = extern struct {
    size: usize,
    alloc: usize,
    data: ?*anyopaque,

    /// Does not clone memory
    pub fn fromArrayList(comptime T: type, array_list: std.ArrayList(T)) Array {
        return Array{
            .size = array_list.items.len * @sizeOf(T),
            .alloc = array_list.capacity * @sizeOf(T),
            .data = array_list.items.ptr,
        };
    }

    pub fn slice(array: Array, comptime T: type) []align(4) T {
        const data = array.data orelse return &[0]T{};
        // The wire protocol/libwayland only guarantee 32-bit word alignment.
        const ptr: [*]align(4) T = @ptrCast(@alignCast(data));
        return ptr[0..@divExact(array.size, @sizeOf(T))];
    }
};

/// A 24.8 signed fixed-point number.
const Fixed = enum(i32) {
    _,

    pub fn toInt(f: Fixed) i24 {
        return @truncate(@intFromEnum(f) >> 8);
    }

    pub fn fromInt(i: i24) Fixed {
        return @enumFromInt(@as(i32, i) << 8);
    }

    pub fn toDouble(f: Fixed) f64 {
        return @as(f64, @floatFromInt(@intFromEnum(f))) / 256;
    }

    pub fn fromDouble(d: f64) Fixed {
        return @enumFromInt(@as(i32, @intFromFloat(d * 256)));
    }
};

const Argument = extern union {
    i: i32,
    u: u32,
    f: Fixed,
    s: ?[*:0]const u8,
    o: ?*Object,
    n: u32,
    a: ?*Array,
    h: i32,
};

fn Dispatcher(comptime Obj: type, comptime Data: type) type {
    const client_side = @hasDecl(Obj, "Event");
    const Payload = if (client_side) Obj.Event else Obj.Request;
    return struct {
        fn dispatcher(
            implementation: ?*const anyopaque,
            object: if (client_side) *client.wl.Proxy else *server.wl.Resource,
            opcode: u32,
            _: *const Message,
            args: [*]Argument,
        ) callconv(.c) c_int {
            inline for (@typeInfo(Payload).@"union".fields, 0..) |payload_field, payload_num| {
                if (payload_num == opcode) {
                    var payload_data: payload_field.type = undefined;
                    if (payload_field.type != void) {
                        inline for (@typeInfo(payload_field.type).@"struct".fields, 0..) |f, i| {
                            switch (@typeInfo(f.type)) {
                                // signed/unsigned ints, fds, new_ids, bitfield enums
                                .int, .@"struct" => @field(payload_data, f.name) = @as(f.type, @bitCast(args[i].u)),
                                // objects, strings, arrays
                                .pointer, .optional => @field(payload_data, f.name) = @as(f.type, @ptrFromInt(@intFromPtr(args[i].o))),
                                // non-bitfield enums
                                .@"enum" => @field(payload_data, f.name) = @as(f.type, @enumFromInt(args[i].i)),
                                else => unreachable,
                            }
                        }
                    }

                    const HandlerFn = fn (*Obj, Payload, Data) void;
                    @as(*const HandlerFn, @ptrCast(@alignCast(implementation)))(
                        @as(*Obj, @ptrCast(object)),
                        @unionInit(Payload, payload_field.name, payload_data),
                        @as(Data, @ptrFromInt(@intFromPtr(object.getUserData()))),
                    );

                    return 0;
                }
            }
            unreachable;
        }
    };
}
