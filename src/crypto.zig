const std = @import("std");
const crypto = std.crypto;

pub const b64_decoder = std.base64.standard.Decoder;
pub const b64_encoder = std.base64.standard.Encoder;
pub const url_encoder = std.base64.Base64Encoder.init(
    std.base64.url_safe_alphabet_chars,
    '=',
);
pub const url_decoder = std.base64.Base64Decoder.init(
    std.base64.url_safe_alphabet_chars,
    '=',
);

pub const KEY_LEN = crypto.nacl.SecretBox.key_length;
pub const NONCE_LEN = crypto.nacl.SecretBox.nonce_length;
pub const TAG_LENGTH = crypto.nacl.SecretBox.tag_length;

pub const DEF_ARGON_PARAMS: crypto.pwhash.argon2.Params = .{
    .t_cost = 3,
    .m_cost = 1 << 16, // NOTE: adjust this
    .threads = 1,
};

pub fn encodeB64(
    alloc: std.mem.Allocator,
    encoder: std.base64.Base64Encoder,
    source: []const u8,
) ![]const u8 {
    const dest = try alloc.alloc(u8, encoder.calcSize(source.len));
    _ = encoder.encode(dest, source);

    return dest;
}

pub fn decodeB64(
    alloc: std.mem.Allocator,
    decoder: std.base64.Base64Decoder,
    source: []const u8,
) ![]const u8 {
    const dest = try alloc.alloc(u8, try decoder.calcSizeForSlice(source));
    errdefer alloc.free(dest);
    try decoder.decode(dest, source);

    return dest;
}

pub fn genNewKey(alloc: std.mem.Allocator) ![]u8 {
    const key = try alloc.alloc(u8, KEY_LEN);
    std.crypto.random.bytes(key);

    return key;
}

pub fn encrypt(
    alloc: std.mem.Allocator,
    key: []const u8,
    plaintext: []const u8,
) !struct { []u8, []u8 } {
    if (key.len != KEY_LEN)
        return error.InvalidKeyLen;

    const nonce: []u8 = try alloc.alloc(u8, NONCE_LEN);
    errdefer alloc.free(nonce);
    crypto.random.bytes(nonce);

    const ciphertext = try alloc.alloc(u8, plaintext.len + TAG_LENGTH);
    errdefer alloc.free(ciphertext);
    crypto.nacl.SecretBox.seal(
        ciphertext,
        plaintext,
        nonce[0..NONCE_LEN].*,
        key[0..KEY_LEN].*,
    );

    return .{ ciphertext, nonce };
}

pub fn decrypt(
    alloc: std.mem.Allocator,
    key: []const u8,
    nonce: []const u8,
    ciphertext: []const u8,
) ![]u8 {
    if (key.len != KEY_LEN)
        return error.AuthenticationFailed;

    const plaintext = try alloc.alloc(u8, ciphertext.len - TAG_LENGTH);
    errdefer alloc.free(plaintext);
    try crypto.nacl.SecretBox.open(
        plaintext,
        ciphertext,
        nonce[0..NONCE_LEN].*,
        key[0..KEY_LEN].*,
    );
    return plaintext;
}
