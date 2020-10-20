const std = @import("std");
const wayland = @import("wayland.zig");

pub const Object = opaque {};

pub const Message = extern struct {
    name: [*:0]const u8,
    signature: [*:0]const u8,
    types: ?[*]const ?*const Interface,
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

/// A 24.8 signed fixed-point number.
pub const Fixed = extern enum(i32) {
    _,

    pub fn toInt(f: Fixed) i24 {
        return @truncate(i24, @enumToInt(f) >> 8);
    }

    pub fn fromInt(i: i24) Fixed {
        return @intToEnum(Fixed, @as(i32, i) << 8);
    }

    pub fn toDouble(f: Fixed) f64 {
        return @intToFloat(f64, @enumToInt(f)) / 256;
    }

    pub fn fromDouble(d: f64) Fixed {
        return @intToEnum(Fixed, @floatToInt(i32, d * 256));
    }
};

pub const Argument = extern union {
    i: i32,
    u: u32,
    f: Fixed,
    s: ?[*:0]const u8,
    o: ?*Object,
    n: u32,
    a: ?*Array,
    h: std.os.fd_t,
};

pub fn Dispatcher(comptime Obj: type, comptime Data: type) type {
    const client = @hasDecl(Obj, "Event");
    const Payload = if (client) Obj.Event else Obj.Request;
    return struct {
        pub fn dispatcher(
            implementation: ?*const c_void,
            object: if (client) *wayland.client.wl.Proxy else *wayland.server.wl.Resource,
            opcode: u32,
            message: *const Message,
            args: [*]Argument,
        ) callconv(.C) c_int {
            inline for (@typeInfo(Payload).Union.fields) |payload_field, payload_num| {
                if (payload_num == opcode) {
                    var payload_data: payload_field.field_type = undefined;
                    inline for (@typeInfo(payload_field.field_type).Struct.fields) |f, i| {
                        if (@typeInfo(f.field_type) == .Enum) {
                            @field(payload_data, f.name) = @intToEnum(f.field_type, args[i].i);
                        } else {
                            @field(payload_data, f.name) = switch (@sizeOf(f.field_type)) {
                                4 => @bitCast(f.field_type, args[i].u),
                                8 => @intToPtr(f.field_type, @ptrToInt(args[i].s)),
                                else => unreachable,
                            };
                        }
                    }

                    @ptrCast(fn (*Obj, Payload, Data) void, implementation)(
                        @ptrCast(*Obj, object),
                        @unionInit(Payload, payload_field.name, payload_data),
                        @intToPtr(Data, @ptrToInt(object.getUserData())),
                    );

                    return 0;
                }
            }
            unreachable;
        }
    };
}

test "Fixed" {
    const testing = std.testing;

    {
        const initial: f64 = 10.5301837;
        const val = Fixed.fromDouble(initial);
        testing.expectWithinMargin(initial, val.toDouble(), 1 / 256.);
        testing.expectEqual(@as(i24, 10), val.toInt());
    }

    {
        const val = Fixed.fromInt(10);
        testing.expectEqual(@as(f64, 10.0), val.toDouble());
        testing.expectEqual(@as(i24, 10), val.toInt());
    }
}
