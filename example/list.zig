const std = @import("std");
const wl = @import("wayland").server.wl;

const B = struct {
    data: u32,
    link: wl.list.Link = undefined,
};

const C = struct {
    data: u32,
    link: wl.list.Link = undefined,

    pub fn getLink(c: *C) *wl.list.Link {
        return &c.link;
    }

    pub fn fromLink(link: *wl.list.Link) *C {
        return @fieldParentPtr(C, "link", link);
    }
};

pub fn main() void {
    {
        var a: wl.list.Head(B, "link") = undefined;
        a.init();

        var one = B{ .data = 1 };
        var two = B{ .data = 2 };
        var three = B{ .data = 3 };
        var four = B{ .data = 4 };
        var five = B{ .data = 5 };

        std.debug.print("length: {} empty: {}\n", .{ a.length(), a.empty() });

        a.append(&one);
        a.append(&two);
        a.append(&three);
        a.append(&four);
        a.append(&five);

        std.debug.print("length: {} empty: {}\n", .{ a.length(), a.empty() });

        {
            std.debug.print("forward\n", .{});
            var it = a.iterator(.forward);
            while (it.next()) |b| std.debug.print("{}\n", .{b.data});
        }

        three.link.remove();
        a.prepend(&three);

        {
            std.debug.print("reverse moved three\n", .{});
            var it = a.iterator(.reverse);
            while (it.next()) |b| std.debug.print("{}\n", .{b.data});
        }
    }
    {
        var a: wl.list.Head(C, null) = undefined;
        a.init();

        var one = C{ .data = 1 };
        var two = C{ .data = 2 };
        var three = C{ .data = 3 };
        var four = C{ .data = 4 };
        var five = C{ .data = 5 };

        std.debug.print("length: {} empty: {}\n", .{ a.length(), a.empty() });

        a.append(&one);
        a.append(&two);
        a.append(&three);
        a.append(&four);
        a.append(&five);

        std.debug.print("length: {} empty: {}\n", .{ a.length(), a.empty() });

        {
            std.debug.print("forward\n", .{});
            var it = a.iterator(.forward);
            while (it.next()) |b| std.debug.print("{}\n", .{b.data});
        }

        three.link.remove();
        a.prepend(&three);

        {
            std.debug.print("reverse moved three\n", .{});
            var it = a.iterator(.reverse);
            while (it.next()) |b| std.debug.print("{}\n", .{b.data});
        }
    }
}
