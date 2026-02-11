const std = @import("std");
const settings = @import("src/settings.zig");
const htmlEscape = @import("src/html_escape.zig").htmlEscape;

const Replacement = struct {
    key: []const u8,
    value: []const u8,
    escape: bool = true,
};

fn applyTemplate(
    allocator: std.mem.Allocator,
    template: []const u8,
    replacements: []const Replacement,
) ![]const u8 {
    var result = try allocator.dupe(u8, template);

    for (replacements) |r| {
        const value_escaped = if (r.escape) try htmlEscape(allocator, r.value) else r.value;
        const replaced = try std.mem.replaceOwned(
            u8,
            allocator,
            result,
            r.key,
            value_escaped,
        );

        allocator.free(result);
        result = replaced;
    }

    return result;
}

pub fn build(b: *std.Build) !void {
    const allocator = b.allocator;
    const cwd = std.fs.cwd();

    // Ugly af lol
    const pages = &[_]struct {
        name: []const u8,
        template_path: []const u8,
        replacements: []const Replacement,
    }{
        .{
            .name = "INDEX_HTML",
            .template_path = "src/template/index.html",
            .replacements = &[_]Replacement{
                .{
                    .key = "{{HELP}}",
                    .value = @embedFile("src/template/help"),
                },
                .{
                    .key = "{{SCRIPT}}",
                    .value = @embedFile("src/template/script.sh"),
                },
                .{
                    .key = "{{stylecode}}",
                    .value = "<code class=\"language-bash\">",
                    .escape = false,
                },
                .{
                    .key = "{{/stylecode}}",
                    .value = "</code>",
                    .escape = false,
                },
                .{
                    .key = "{{URL}}",
                    .value = settings.URL,
                },
            },
        },
        .{
            .name = "VIEW_HTML",
            .template_path = "src/template/view.html",
            .replacements = &[_]Replacement{},
        },
        .{
            .name = "NOT_FOUND_HTML",
            .template_path = "src/template/404.html",
            .replacements = &[_]Replacement{
                .{
                    .key = "{{ERROR}}",
                    .value = @embedFile("src/template/404"),
                },
            },
        },
        .{
            .name = "ERR",
            .template_path = "src/template/error.html",
            .replacements = &[_]Replacement{},
        },
        .{
            .name = "HELP",
            .template_path = "src/template/help",
            .replacements = &[_]Replacement{
                .{
                    .key = "{{SCRIPT}}",
                    .value = @embedFile("src/template/script.sh"),
                    .escape = false,
                },
                .{
                    .key = "{{stylecode}}",
                    .value = "",
                },
                .{
                    .key = "{{/stylecode}}",
                    .value = "",
                },
                .{
                    .key = "{{URL}}",
                    .value = settings.URL,
                },
            },
        },
        .{
            .name = "NOT_FOUND",
            .template_path = "src/template/404",
            .replacements = &[_]Replacement{},
        },
    };

    var generated_code: std.ArrayList(u8) = .empty;
    defer generated_code.deinit(allocator);

    try generated_code.appendSlice(allocator, "pub const templates = struct {\n");

    for (
        pages,
    ) |p| {
        const file = try cwd.readFileAlloc(allocator, p.template_path, (try cwd.statFile(p.template_path)).size);
        defer allocator.free(file);
        const rendered = applyTemplate(allocator, file, p.replacements) catch unreachable;
        defer allocator.free(rendered);

        try generated_code.appendSlice(allocator, "    pub const ");
        try generated_code.appendSlice(allocator, p.name);
        try generated_code.appendSlice(allocator, ": []const u8 = \n\\\\");
        for (rendered) |c| {
            if (c == '"') {
                try generated_code.appendSlice(allocator, "\"");
            } else if (c == '\\') {
                try generated_code.appendSlice(allocator, "\\");
            } else if (c == '\n') {
                try generated_code.appendSlice(allocator, "\n\\\\");
            } else {
                try generated_code.appendSlice(allocator, &[_]u8{c});
            }
        }
        try generated_code.appendSlice(allocator, "\n;\n");
    }

    try generated_code.appendSlice(allocator, "};\n");

    const code = try generated_code.toOwnedSlice(allocator);
    defer allocator.free(code);

    cwd.makePath("src/generated") catch {};
    cwd.writeFile(.{
        .sub_path = "src/generated/templates.zig",
        .data = code,
        .flags = .{
            .truncate = true,
        },
    }) catch |err| {
        std.debug.print("error here {}", .{err});
    };

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zap = b.dependency("zap", .{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "pastebin",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.addImport("zap", zap.module("zap"));

    b.installArtifact(exe);

    const run_exe = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_exe.step);

    const tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    }) });

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_tests.step);
}
