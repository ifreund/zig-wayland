const std = @import("std");

pub const Object = opaque{};

pub const Message = extern struct {
    name: [*:0]const u8,
    signature: [*:0]const u8,
    types: [*]const ?*const Interface,
};

pub const Interface = extern struct {
    name: [*:0]const u8,
    version: i32,
    method_count: i32,
    methods: ?[*]const Message,
    event_count: i32,
    events: ?[*]const Message,
};

pub const Array = extern struct {
    size: usize,
    alloc: usize,
    data: *c_void,
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

pub const Fixed = extern enum(i32) {
    _,

    pub fn toInt(f: Fixed) i24 {
        return @enumToInt(f) >> 8;
    }

    pub fn fromInt(i: i24) Fixed {
        return @intToEnum(Fixed, @as(i32, i) << 8);
    }

    pub fn toDouble() i24 {
        // TODO
    }
    pub fn fromDouble(d: f64) Fixed {
        // TODO
    }
};

pub const Argument = extern union {
    i: i32,
    u: u32,
    f: Fixed,
    s: ?[*:0]const u8,
    o: ?*Object,
    a: ?*Array,
    h: std.os.fd_t,
};