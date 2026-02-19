const std = @import("std");
const paste = @import("paste.zig");
const html = @import("generated/templates.zig").templates;
const htmlEscape = @import("html_escape.zig").htmlEscape;
const settings = @import("settings.zig");
const clean = @import("db.zig").clean;

const zap = @import("zap");

fn notFound(r: *const zap.Request) !void {
    r.setStatus(.not_found);
    if (isBrowser(r)) {
        try r.sendBody(html.NOT_FOUND_HTML);
    } else try r.sendBody(html.NOT_FOUND);
}

fn sendErrorRaw(r: *const zap.Request, status: zap.http.StatusCode, err: anyerror) !void {
    r.setStatus(status);
    var buf: [256]u8 = undefined;
    const message = try std.fmt.bufPrint(&buf, "{s}\n", .{@errorName(err)});
    try r.sendBody(message);
}

fn sendError(alloc: std.mem.Allocator, r: *const zap.Request, status: zap.http.StatusCode, err: anyerror) !void {
    r.setStatus(status);
    if (isBrowser(r)) {
        const message = try std.mem.replaceOwned(u8, alloc, html.ERR, "{{ERROR}}", @errorName(err));
        try r.sendBody(message);
    } else try r.sendBody(@errorName(err));
}

fn isBrowser(r: *const zap.Request) bool {
    const ua = r.getHeader("user-agent") orelse "unknown";
    return (std.mem.indexOf(u8, ua, "Windows NT") != null or
        std.mem.indexOf(u8, ua, "Macintosh") != null or
        std.mem.indexOf(u8, ua, "Linux") != null or
        std.mem.indexOf(u8, ua, "Android") != null or
        std.mem.indexOf(u8, ua, "iPhone") != null or
        std.mem.indexOf(u8, ua, "iPad") != null or
        std.mem.indexOf(u8, ua, "iPod") != null or
        std.mem.indexOf(u8, ua, "CrOS") != null or
        std.mem.indexOf(u8, ua, "FreeBSD") != null or
        std.mem.indexOf(u8, ua, "OpenBSD") != null or
        std.mem.indexOf(u8, ua, "NetBSD") != null);
}

const Context = struct {
    pub fn unhandledRequest(
        _: *Context,
        _: std.mem.Allocator,
        r: zap.Request,
    ) anyerror!void {
        try notFound(&r);
    }

    pub fn unhandledError(_: *Context, r: zap.Request, err: anyerror) void {
        r.sendError(err, if (@errorReturnTrace()) |t| t.* else null, 505);
    }
};

const RootEndpoint = struct {
    path: []const u8 = "/",
    error_strategy: zap.Endpoint.ErrorStrategy = .log_to_response,

    fn parseUrlGet(path: []const u8) struct {
        ?[]const u8,
        ?[]const u8,
        ?[]const u8,
    } {
        var it = std.mem.splitAny(u8, path, "/");

        _ = it.next();

        const id_opt = it.next();
        const key = it.next();

        if (id_opt) |id_ext| {
            if (std.mem.indexOfScalar(u8, id_ext, '.')) |dot_index| {
                const id = id_ext[0..dot_index];
                const ext = id_ext[dot_index + 1 ..];

                return .{ id, ext, key };
            } else return .{ id_ext, null, key };
        } else {
            return .{ null, null, key };
        }
    }

    fn setFileName(
        alloc: std.mem.Allocator,
        r: *const zap.Request,
        id: []const u8,
        ext: []const u8,
    ) !void {
        const content_disposition = try std.fmt.allocPrint(alloc, "attachment; filename=paste:{s}.{s}", .{ id, ext });
        try r.setHeader("Content-Disposition", content_disposition);
    }

    fn getFileType(ext: ?[]const u8) ?settings.FileType {
        if (ext) |e| {
            inline for (settings.file_types) |ft| {
                if (std.mem.eql(u8, ft.ext, e))
                    return ft;
            }
        }
        return null;
    }

    pub fn get(
        _: *RootEndpoint,
        arena: std.mem.Allocator,
        _: *Context,
        r: zap.Request,
    ) !void {
        const path = r.path orelse "/";
        const id_opt, const ext_opt, const key = parseUrlGet(path);
        const id = id_opt orelse "";
        const ext = ext_opt orelse "text";
        r.setStatus(.ok);

        if (id.len > 0) {
            const plaintext = paste.getPaste(arena, id, key) catch |err| {
                switch (err) {
                    error.FileNotFound => {
                        try notFound(&r);
                    },
                    else => try sendError(
                        arena,
                        &r,
                        .internal_server_error,
                        err,
                    ),
                }
                return;
            };

            const ft = getFileType(ext);

            if (ft == null) {
                if (isBrowser(&r)) {
                    const escaped_text = try htmlEscape(arena, plaintext);
                    var body = try std.mem.replaceOwned(
                        u8,
                        arena,
                        html.VIEW_HTML,
                        "{{TEXT}}",
                        escaped_text,
                    );
                    body = try std.mem.replaceOwned(u8, arena, body, "{{LANG}}", ext);
                    try r.sendBody(body);
                } else try r.sendBody(plaintext);
            } else {
                if (!ft.?.displayable) {
                    try setFileName(arena, &r, id, ft.?.ext);
                }
                try r.setHeader("Content-Type", ft.?.mime);
                try r.sendBody(plaintext);
            }
        } else {
            if (isBrowser(&r)) {
                try r.sendBody(html.INDEX_HTML);
            } else try r.sendBody(html.HELP);
        }
    }

    pub fn delete(
        _: *RootEndpoint,
        arena: std.mem.Allocator,
        _: *Context,
        r: zap.Request,
    ) !void {
        const path = r.path orelse "/";
        const id_opt, _, const key = parseUrlGet(path);
        const id = id_opt orelse "";
        r.setStatus(.ok);

        if (id.len > 1) {
            paste.deletePaste(arena, id, key) catch |err| {
                switch (err) {
                    error.FileNotFound => {
                        try notFound(&r);
                    },
                    else => try sendErrorRaw(&r, .internal_server_error, err),
                }
                return;
            };
            try r.sendBody("deleted\n");
        } else {
            try notFound(&r);
        }
    }

    pub fn post(
        _: *RootEndpoint,
        arena: std.mem.Allocator,
        _: *Context,
        r: zap.Request,
    ) !void {
        const content = r.body orelse return;

        r.parseQuery();

        const secure = if (r.getParamSlice("s") != null) true else false;
        var ext = r.getParamSlice("ext");
        if (ext != null and ext.?.len == 0) ext = null;

        const id, const key_opt = paste.createPaste(
            arena,
            .{ .text = content, .secure = secure },
        ) catch |err| {
            try sendErrorRaw(&r, .internal_server_error, err);
            return;
        };

        const full_url = if (ext) |ext_val|
            try std.fmt.allocPrint(
                arena,
                "{s}/{s}.{s}/{s}",
                .{ settings.URL, id, ext_val, key_opt orelse "" },
            )
        else
            try std.fmt.allocPrint(
                arena,
                "{s}/{s}/{s}",
                .{ settings.URL, id, key_opt orelse "" },
            );

        r.setStatus(.created);
        try r.sendBody(full_url);
    }
};

fn processArgs(alloc: std.mem.Allocator) !void {
    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);
    if (args.len == 0) {
        std.debug.print("No arguments provided.\n", .{});
        return;
    }

    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--clean")) {
            try clean(alloc);
            std.process.exit(0);
        }
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .thread_safe = true,
    }){};
    defer std.debug.print("Memory Leaks: {}\n", .{gpa.deinit()});

    const allocator = gpa.allocator();

    try processArgs(allocator);

    var context = Context{};
    const app = zap.App.Create(Context);
    try app.init(allocator, &context, .{});
    defer app.deinit();

    var root = RootEndpoint{};
    try app.register(&root);

    try app.listen(.{
        .interface = "0.0.0.0",
        .port = 8081,
        .public_folder = "public",
        .max_body_size = settings.MAX_SIZE,
    });

    zap.start(.{
        .threads = 1,
        .workers = 1,
    });
}
