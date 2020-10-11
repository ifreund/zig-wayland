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
                        @field(payload_data, f.name) = switch (@sizeOf(f.field_type)) {
                            4 => @bitCast(f.field_type, args[i].u),
                            8 => @intToPtr(f.field_type, @ptrToInt(args[i].s)),
                            else => unreachable,
                        };
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
