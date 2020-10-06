const std = @import("std");

pub const Object = opaque {};

pub const Message = extern struct {
    name: [*:0]const u8,
    signature: [*:0]const u8,
    types: [*]const ?*const Interface,
};

pub const Interface = extern struct {
    name: [*:0]const u8,
    version: c_int,
    method_count: c_int,
    methods: ?[*]const Message,
    event_count: c_int,
    events: ?[*]const Message,
};

pub const Array = extern struct {
    size: usize,
    alloc: usize,
    data: *c_void,
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
