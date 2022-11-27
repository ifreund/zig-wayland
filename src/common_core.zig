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
    data: ?*anyopaque,

    /// Does not clone memory
    pub fn fromArrayList(comptime T: type, list: std.ArrayList(T)) Array {
        return Array{
            .size = list.items.len * @sizeOf(T),
            .alloc = list.capacity * @sizeOf(T),
            .data = list.items.ptr,
        };
    }

    pub fn slice(array: Array, comptime T: type) []T {
        const data = array.data orelse return &[0]T{};
        // The wire protocol/libwayland only guarantee 32-bit word alignment.
        const ptr = @ptrCast([*]T, @alignCast(4, data));
        return ptr[0..@divExact(array.size, @sizeOf(T))];
    }
};

/// A 24.8 signed fixed-point number.
pub const Fixed = enum(i32) {
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
    h: i32,
};

pub fn Dispatcher(comptime Obj: type, comptime Data: type) type {
    const client = @hasDecl(Obj, "Event");
    const Payload = if (client) Obj.Event else Obj.Request;
    return struct {
        pub fn dispatcher(
            implementation: ?*const anyopaque,
            object: if (client) *wayland.client.wl.Proxy else *wayland.server.wl.Resource,
            opcode: u32,
            _: *const Message,
            args: [*]Argument,
        ) callconv(.C) c_int {
            inline for (@typeInfo(Payload).Union.fields) |payload_field, payload_num| {
                if (payload_num == opcode) {
                    var payload_data: payload_field.field_type = undefined;
                    if (payload_field.field_type != void) {
                        inline for (@typeInfo(payload_field.field_type).Struct.fields) |f, i| {
                            switch (@typeInfo(f.field_type)) {
                                // signed/unsigned ints, fds, new_ids, bitfield enums
                                .Int, .Struct => @field(payload_data, f.name) = @bitCast(f.field_type, args[i].u),
                                // objects, strings, arrays
                                .Pointer, .Optional => @field(payload_data, f.name) = @intToPtr(f.field_type, @ptrToInt(args[i].o)),
                                // non-bitfield enums
                                .Enum => @field(payload_data, f.name) = @intToEnum(f.field_type, args[i].i),
                                else => unreachable,
                            }
                        }
                    }

                    @ptrCast(*const fn (*Obj, Payload, Data) void, implementation)(
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
