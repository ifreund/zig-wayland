const std = @import("std");
const wayland = @import("wayland");
const wl = wayland.client.wl;

pub fn main() !void {
    const display = try wl.Display.connect(null);
    const registry = try display.getRegistry();
    var foo: u32 = 42;
    registry.setListener(*u32, listener, &foo);
    _ = try display.roundtrip();
}

fn listener(_: *wl.Registry, event: wl.Registry.Event, data: *u32) void {
    std.debug.print("foo is {}\n", .{data.*});
    std.debug.print("event is {}\n", .{event});
}
