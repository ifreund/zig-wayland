const std = @import("std");
const wl = @import("wayland-client");

pub fn main() !void {
    const display = try wl.Display.connect(null);
    const registry = try display.getRegistry();
    var foo: u32 = 42;
    try registry.addListener(*u32, wl.Registry.Listener(*u32){
        .global = global,
        .global_remove = global_remove,
    }, &foo);
    _ = try display.roundtrip();
}

fn global(data: *u32, registry: *wl.Registry, name: u32, interface: [*:0]const u8, version: u32) callconv(.C) void {
    std.debug.warn("foo is {}\n", .{data.*});
    std.debug.warn("interface is {}\n", .{interface});
}

fn global_remove(data: *u32, registry: *wl.Registry, name: u32) callconv(.C) void {
    // do nothing
}
