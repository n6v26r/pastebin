const std = @import("std");

pub fn htmlEscape(alloc: std.mem.Allocator, input: []const u8) ![]u8 {
    var list: std.ArrayList(u8) = .empty;
    defer list.deinit(alloc);

    for (input) |c| {
        switch (c) {
            '<' => try list.appendSlice(alloc, "&lt;"),
            '>' => try list.appendSlice(alloc, "&gt;"),
            '&' => try list.appendSlice(alloc, "&amp;"),
            '"' => try list.appendSlice(alloc, "&quot;"),
            else => try list.append(alloc, c),
        }
    }

    return list.toOwnedSlice(alloc);
}
