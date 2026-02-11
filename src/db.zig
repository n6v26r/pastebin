const std = @import("std");
const settings = @import("settings.zig");

const fs = std.fs.cwd();

pub fn save(alloc: std.mem.Allocator, filename: []const u8, json_data: []const u8) !void {
    const path = try std.fmt.allocPrint(alloc, settings.SAVE_PATH ++ "/{s}", .{filename});
    defer alloc.free(path);

    var file = try fs.createFile(path, .{ .truncate = true, .lock = .exclusive });
    defer file.close();

    const buffer = try alloc.alloc(u8, 1024);
    defer alloc.free(buffer);
    var writer = file.writer(buffer);
    try writer.interface.writeAll(json_data);
    try writer.interface.flush();
}

pub fn read(alloc: std.mem.Allocator, filename: []const u8) ![]const u8 {
    const path = try std.fmt.allocPrint(alloc, settings.SAVE_PATH ++ "/{s}", .{filename});
    defer alloc.free(path);

    var file = try fs.openFile(path, .{ .lock = .shared });
    defer file.close();

    const buffer = try alloc.alloc(u8, 1024);
    defer alloc.free(buffer);
    var reader = file.reader(buffer);
    const content = try reader.interface.readAlloc(alloc, try file.getEndPos());

    return content;
}

pub fn deleteFile(alloc: std.mem.Allocator, filename: []const u8) !void {
    const path = try std.fmt.allocPrint(alloc, settings.SAVE_PATH ++ "/{s}", .{filename});
    defer alloc.free(path);

    try fs.deleteFile(path);
}

pub fn delete(alloc: std.mem.Allocator, key: []const u8) !void {
    const filename = try getFileName(alloc, key);
    defer alloc.free(filename);

    return deleteFile(alloc, filename);
}

pub const Packet = struct {
    text: []const u8,
    nonce: ?[]const u8,
    ttl: i64,

    pub fn getJson(self: *const Packet, alloc: std.mem.Allocator) ![]const u8 {
        const json_data = try std.fmt.allocPrint(
            alloc,
            \\{{"text":"{s}","nonce":"{s}","ttl":"{d}"}}
        ,
            .{ self.text, self.nonce orelse "", self.ttl },
        );

        return json_data;
    }

    pub fn deinit(self: *const Packet, alloc: std.mem.Allocator) void {
        alloc.free(self.text);
        if (self.nonce) |nonce|
            alloc.free(nonce);
    }
};

fn getFileName(alloc: std.mem.Allocator, id: []const u8) ![]const u8 {
    const filename = try std.fmt.allocPrint(alloc, "paste:{s}.json", .{id});
    return filename;
}

pub fn clean(alloc: std.mem.Allocator) !void {
    const currtime = std.time.timestamp();
    const dir = try std.fs.cwd().openDir(
        settings.SAVE_PATH,
        .{ .iterate = true },
    );

    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind != .file) continue;

        const filename = entry.name;
        const filedata = try getFile(alloc, filename);
        defer filedata.deinit(alloc);

        if (filedata.ttl < currtime) {
            try deleteFile(alloc, filename);
        }
    }
}

pub fn getFile(
    alloc: std.mem.Allocator,
    filename: []const u8,
) !Packet {
    const reply = try read(alloc, filename);
    defer alloc.free(reply);

    const parsed = try std.json.parseFromSlice(Packet, alloc, reply, .{});
    defer parsed.deinit();

    const text = try alloc.alloc(u8, parsed.value.text.len);
    @memcpy(text, parsed.value.text);

    var nonce: ?[]const u8 = null;
    if (parsed.value.nonce) |n| {
        const nonce_text = try alloc.alloc(u8, n.len);
        @memcpy(nonce_text, n);
        if (nonce_text.len > 0) {
            nonce = nonce_text;
        } else alloc.free(nonce_text);
    }

    return .{
        .text = text,
        .nonce = nonce,
        .ttl = parsed.value.ttl,
    };
}

pub fn get(
    alloc: std.mem.Allocator,
    id: []const u8,
) !Packet {
    const filename = try getFileName(alloc, id);
    defer alloc.free(filename);

    return getFile(alloc, filename);
}

pub fn set(
    alloc: std.mem.Allocator,
    id: []const u8,
    paste: Packet,
) !void {
    const key = try getFileName(alloc, id);
    defer alloc.free(key);

    const json_data = try paste.getJson(alloc);
    defer alloc.free(json_data);

    const path = try std.fmt.allocPrint(alloc, settings.SAVE_PATH ++ "/{s}", .{key});
    defer alloc.free(path);

    var file = try fs.createFile(path, .{ .truncate = false, .exclusive = true, .lock = .exclusive });
    defer file.close();

    const buffer = try alloc.alloc(u8, 1024);
    defer alloc.free(buffer);
    var writer = file.writer(buffer);
    try writer.interface.writeAll(json_data);
    try writer.interface.flush();
}
