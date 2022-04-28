const std = @import("std");
const wayland = @import("wayland");
const wl = wayland.client.wl;

pub fn main() !void {
    const display = try wl.Display.connect(null);
    const registry = try display.getRegistry();
    var running: bool = true;
    registry.setListener(*bool, listener, &running);
    while (running) {
        if (display.roundtrip() != .SUCCESS) return error.RoundtripFailed;
    }
}

fn listener(registry: *wl.Registry, event: wl.Registry.Event, running: *bool) void {
    switch (event) {
        .global => |global| {
            if (std.cstr.cmp(global.interface, wl.Seat.getInterface().name) == 0) {
                const seat = registry.bind(global.name, wl.Seat, 1) catch return;
                seat.setListener(*bool, seatListener, running);
            }
        },
        .global_remove => {},
    }
}

fn seatListener(_: *wl.Seat, event: wl.Seat.Event, running: *bool) void {
    switch (event) {
        .capabilities => |data| {
            std.debug.print("Seat capabilities\n  Pointer {}\n  Keyboard {}\n  Touch {}\n", .{
                data.capabilities.pointer,
                data.capabilities.keyboard,
                data.capabilities.touch,
            });
            running.* = false;
        },
        .name => {},
    }
}
