const std = @import("std");
const wl = @import("wayland").server.wl;

const A = struct {
    list: wl.List(B, "link").Head,
};

const B = struct {
    data: u32,
    link: wl.List(B, "link").Link = undefined,
};

pub fn main() void {
    var a: A = undefined;
    a.list.init();

    var one = B{ .data = 1 };
    var two = B{ .data = 2 };
    var three = B{ .data = 3 };
    var four = B{ .data = 4 };
    var five = B{ .data = 5 };

    a.list.append(&one.link);
    a.list.append(&two.link);
    a.list.append(&three.link);
    a.list.append(&four.link);
    a.list.append(&five.link);

    {
        std.debug.print("forward\n", .{});
        var it = a.list.iterator(.forward);
        while (it.next()) |b| std.debug.print("{}\n", .{b.data});
    }

    three.link.remove();
    a.list.prepend(&three.link);

    {
        std.debug.print("reverse moved three\n", .{});
        var it = a.list.iterator(.reverse);
        while (it.next()) |b| std.debug.print("{}\n", .{b.data});
    }
}
