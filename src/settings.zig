pub const DEF_TTL = 60 * 60 * 24 * 30;
pub const URL = "https://pasteit.zip";
pub const MAX_SIZE = 5 * 1024 * 1024;
pub const SAVE_PATH = "pastes";
pub const ID_MIN_LEN = 4;
pub const ID_MAX_LEN = 6;
pub const ID_LEN_MAX_COLLISIONS = 32;

pub const FileType = struct {
    ext: []const u8,
    mime: []const u8,
    displayable: bool,
};

pub const file_types = [_]FileType{
    .{ .ext = "html", .mime = "text/html", .displayable = true },
    .{ .ext = "json", .mime = "application/json", .displayable = true },
    .{ .ext = "xml", .mime = "application/xml", .displayable = true },

    .{ .ext = "png", .mime = "image/png", .displayable = true },
    .{ .ext = "jpg", .mime = "image/jpeg", .displayable = true },
    .{ .ext = "jpeg", .mime = "image/jpeg", .displayable = true },
    .{ .ext = "gif", .mime = "image/gif", .displayable = true },
    .{ .ext = "webp", .mime = "image/webp", .displayable = true },
    .{ .ext = "bmp", .mime = "image/bmp", .displayable = true },
    .{ .ext = "svg", .mime = "image/svg+xml", .displayable = true },
    .{ .ext = "ico", .mime = "image/x-icon", .displayable = true },

    .{ .ext = "mp3", .mime = "audio/mpeg", .displayable = true },
    .{ .ext = "wav", .mime = "audio/wav", .displayable = true },
    .{ .ext = "ogg", .mime = "audio/ogg", .displayable = true },
    .{ .ext = "flac", .mime = "audio/flac", .displayable = true },
    .{ .ext = "mp4", .mime = "video/mp4", .displayable = true },
    .{ .ext = "webm", .mime = "video/webm", .displayable = true },
    .{ .ext = "mov", .mime = "video/quicktime", .displayable = true },
    .{ .ext = "avi", .mime = "video/x-msvideo", .displayable = false },
    .{ .ext = "mkv", .mime = "video/x-matroska", .displayable = false },

    .{ .ext = "pdf", .mime = "application/pdf", .displayable = true },

    .{ .ext = "doc", .mime = "application/msword", .displayable = false },
    .{
        .ext = "docx",
        .mime = "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        .displayable = false,
    },
    .{
        .ext = "xls",
        .mime = "application/vnd.ms-excel",
        .displayable = false,
    },
    .{
        .ext = "xlsx",
        .mime = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        .displayable = false,
    },
    .{
        .ext = "ppt",
        .mime = "application/vnd.ms-powerpoint",
        .displayable = false,
    },
    .{
        .ext = "pptx",
        .mime = "application/vnd.openxmlformats-officedocument.presentationml.presentation",
        .displayable = false,
    },

    .{
        .ext = "odt",
        .mime = "application/vnd.oasis.opendocument.text",
        .displayable = false,
    },
    .{
        .ext = "ods",
        .mime = "application/vnd.oasis.opendocument.spreadsheet",
        .displayable = false,
    },
    .{
        .ext = "odp",
        .mime = "application/vnd.oasis.opendocument.presentation",
        .displayable = false,
    },

    .{ .ext = "zip", .mime = "application/zip", .displayable = false },
    .{ .ext = "rar", .mime = "application/vnd.rar", .displayable = false },
    .{
        .ext = "7z",
        .mime = "application/x-7z-compressed",
        .displayable = false,
    },
    .{ .ext = "tar", .mime = "application/x-tar", .displayable = false },
    .{ .ext = "gz", .mime = "application/gzip", .displayable = false },
    .{ .ext = "bz2", .mime = "application/x-bzip2", .displayable = false },

    .{
        .ext = "psd",
        .mime = "image/vnd.adobe.photoshop",
        .displayable = false,
    },
    .{ .ext = "ai", .mime = "application/postscript", .displayable = false },
    .{ .ext = "eps", .mime = "application/postscript", .displayable = false },

    .{
        .ext = "exe",
        .mime = "application/x-msdownload",
        .displayable = false,
    },
    .{
        .ext = "dll",
        .mime = "application/x-msdownload",
        .displayable = false,
    },
    .{
        .ext = "bin",
        .mime = "application/octet-stream",
        .displayable = false,
    },
    .{
        .ext = "class",
        .mime = "application/octet-stream",
        .displayable = false,
    },
    .{
        .ext = "so",
        .mime = "application/octet-stream",
        .displayable = false,
    },
    .{
        .ext = "dylib",
        .mime = "application/octet-stream",
        .displayable = false,
    },
    .{
        .ext = "jar",
        .mime = "application/java-archive",
        .displayable = false,
    },

    .{ .ext = "ttf", .mime = "font/ttf", .displayable = false },
    .{ .ext = "otf", .mime = "font/otf", .displayable = false },
    .{ .ext = "woff", .mime = "font/woff", .displayable = false },
    .{ .ext = "woff2", .mime = "font/woff2", .displayable = false },

    .{
        .ext = "ipynb",
        .mime = "application/octet-stream",
        .displayable = false,
    },

    .{
        .ext = "file",
        .mime = "application/octet-stream",
        .displayable = false,
    },
};
