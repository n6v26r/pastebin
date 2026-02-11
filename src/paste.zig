const std = @import("std");
const settings = @import("settings.zig");
const db = @import("db.zig");
const crypto = @import("crypto.zig");

pub const PasteData = struct {
    text: []const u8,
    secure: bool,
    ttl: i64 = settings.DEF_TTL,
};

pub fn generateNewId(alloc: std.mem.Allocator, len: usize) ![]const u8 {
    const alphabet = std.base64.url_safe_alphabet_chars;
    const id = try alloc.alloc(u8, len);
    std.crypto.random.bytes(id);
    for (id) |*b| {
        b.* = alphabet[b.* % alphabet.len];
    }
    return id;
}

fn setNewId(alloc: std.mem.Allocator, packet: db.Packet) ![]const u8 {
    var len: usize = settings.ID_MIN_LEN;
    while (len <= settings.ID_MAX_LEN) : (len += 1) {
        var attempts: usize = 0;
        while (attempts < settings.ID_LEN_MAX_COLLISIONS) : (attempts += 1) {
            const id = try generateNewId(alloc, len);
            db.set(alloc, id, packet) catch |err| switch (err) {
                error.PathAlreadyExists => {
                    alloc.free(id);
                    continue;
                },
                else => {
                    alloc.free(id);
                    return err;
                },
            };
            return id;
        }
    }

    return error.IdSpaceExhausted;
}

pub fn createPaste(alloc: std.mem.Allocator, p: PasteData) !struct {
    []const u8,
    ?[]const u8,
} {
    const ttl = std.time.timestamp() + p.ttl;
    if (p.secure) {
        const key: [crypto.KEY_LEN]u8 = try crypto.genNewKey(alloc);

        const ciphertext, const nonce = try crypto.encrypt(alloc, key, p.text);
        defer alloc.free(ciphertext);
        defer alloc.free(nonce);

        const ciphertext_encoded = try crypto.encodeB64(
            alloc,
            crypto.b64_encoder,
            ciphertext,
        );
        const nonce_encoded = try crypto.encodeB64(
            alloc,
            crypto.b64_encoder,
            nonce,
        );
        defer alloc.free(ciphertext_encoded);
        defer alloc.free(nonce_encoded);

        const id = try setNewId(
            alloc,
            db.Packet{
                .text = ciphertext_encoded,
                .nonce = nonce_encoded,
                .ttl = ttl,
            },
        );
        return .{ id, try crypto.encodeB64(
            alloc,
            crypto.url_encoder,
            &key,
        ) };
    }

    const text_encoded = try crypto.encodeB64(
        alloc,
        crypto.b64_encoder,
        p.text,
    );
    const id = try setNewId(
        alloc,
        db.Packet{
            .text = text_encoded,
            .nonce = null,
            .ttl = ttl,
        },
    );
    return .{ id, null };
}

pub fn getPaste(
    alloc: std.mem.Allocator,
    id: []const u8,
    key: ?[]const u8,
) ![]const u8 {
    const data = try db.get(alloc, id);

    defer alloc.free(data.text);
    defer if (data.nonce) |nonce| alloc.free(nonce);

    const text_decoded = try crypto.decodeB64(
        alloc,
        crypto.b64_decoder,
        data.text,
    );
    if (data.nonce) |nonce| {
        const nonce_decoded = try crypto.decodeB64(
            alloc,
            crypto.b64_decoder,
            nonce,
        );
        defer alloc.free(text_decoded);
        defer alloc.free(nonce_decoded);

        const k = key orelse "";
        const key_decoded = try crypto.decodeB64(alloc, crypto.url_decoder, k);
        defer alloc.free(key_decoded);

        const plaintext = try crypto.decrypt(
            alloc,
            key_decoded,
            nonce_decoded,
            text_decoded,
        );

        return plaintext;
    }
    return text_decoded;
}

pub fn deletePaste(
    alloc: std.mem.Allocator,
    id: []const u8,
    key: ?[]const u8,
) ![]const u8 {
    const plaintext = try getPaste(alloc, id, key);

    try db.delete(alloc, id);

    return plaintext;
}
