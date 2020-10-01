const std = @import("std");
const client = @import("client.zig");

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

pub fn Dispatcher(comptime ObjectT: type, comptime DataT: type) type {
    return struct {
        pub fn dispatcher(
            implementation: ?*const c_void,
            proxy: *client.Proxy,
            opcode: u32,
            message: *const Message,
            args: [*]Argument,
        ) callconv(.C) i32 {
            inline for (@typeInfo(ObjectT.Event).Union.fields) |event_field, event_num| {
                if (event_num == opcode) {
                    var event_data: event_field.field_type = undefined;
                    inline for (@typeInfo(event_field.field_type).Struct.fields) |f, i| {
                        @field(event_data, f.name) = switch (@sizeOf(f.field_type)) {
                            4 => @bitCast(f.field_type, args[i].u),
                            8 => @ptrCast(f.field_type, args[i].s),
                            else => unreachable,
                        };
                    }

                    const listener = @ptrCast(fn (object: *ObjectT, event: ObjectT.Event, data: DataT) void, implementation);
                    listener(
                        @ptrCast(*ObjectT, proxy),
                        @unionInit(ObjectT.Event, event_field.name, event_data),
                        @intToPtr(DataT, @ptrToInt(proxy.getUserData())),
                    );

                    return 0;
                }
            }
            unreachable;
        }
    };
}
