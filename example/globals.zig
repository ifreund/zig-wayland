const std = @import("std");
const wl = @import("wayland-client");

pub fn main() !void {
    const display = try wl.Display.connect(null);
    const registry = try display.getRegistry();
    var foo: u32 = 42;
    try registry.setListener(*u32, listener, &foo);
    _ = try display.roundtrip();
}

fn listener(registry: *wl.Registry, event: wl.Registry.Event, data: *u32) void {
    std.debug.warn("foo is {}\n", .{data.*});
    std.debug.warn("event is {}\n", .{event});
}
