const std = @import("std");
const wl = @import("wayland").server.wl;

const Foo = struct {
    bar: []const u8,
};

pub fn main() anyerror!void {
    var listen: wl.Listener(void) = undefined;
    listen.setNotify(not);

    var signal: wl.Signal(void) = undefined;
    signal.init();

    signal.add(&listen);

    signal.emit();
    signal.emit();

    var listen2: wl.Listener(*Foo) = undefined;
    listen2.setNotify(not2);

    var signal2: wl.Signal(*Foo) = undefined;
    signal2.init();

    signal2.add(&listen2);

    var foo = Foo{ .bar = "it's a trap!" };
    var foo2 = Foo{ .bar = "nevermind..." };

    signal2.emit(&foo);
    signal2.emit(&foo2);
}

fn not(_: *wl.Listener(void)) void {
    std.debug.print("notified\n", .{});
}

fn not2(_: *wl.Listener(*Foo), foo: *Foo) void {
    std.debug.print("{s}\n", .{foo.bar});
}
