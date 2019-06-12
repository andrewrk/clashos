pub fn get(ptr: *u32) PropertiesStep {
    return PropertiesStep{ .Get = ptr };
}

pub fn in(ptr: *u32) PropertiesStep {
    return PropertiesStep{ .In = ptr };
}

const TAG_LAST_SENTINEL = 0;
pub fn lastTagSentinel() PropertiesStep {
    return tag(TAG_LAST_SENTINEL, 0);
}

pub fn set(ptr: *u32) PropertiesStep {
    return PropertiesStep{ .Set = ptr };
}

pub fn tag(the_tag: u32, length: u32) PropertiesStep {
    return PropertiesStep{ .TagAndLength = TagAndLength{ .tag = the_tag, .length = length } };
}

pub const PropertiesStep = union(enum) {
    Get: *u32,
    In: *u32,
    Set: *u32,
    TagAndLength: TagAndLength,
};

const TagAndLength = struct {
    tag: u32,
    length: u32,
};

pub fn callVideoCoreProperties(codes: []PropertiesStep) !void {
    if(codes[codes.len - 1].TagAndLength.tag != TAG_LAST_SENTINEL) {
        panic(@errorReturnTrace(), "video core mailbox buffer missing last tag sentinel");
    }
    var words: [512]u32 align(16) = undefined;
    var buf = SliceIterator.of(u32).init(&words);

    var buffer_length_in_bytes: u32 = 0;
    try buf.add(buffer_length_in_bytes);
    const BUFFER_REQUEST = 0;
    try buf.add(BUFFER_REQUEST);
    var next_tag_index: ?u32 = null;
    for (codes) |code| {
        switch(code) {
            PropertiesStep.TagAndLength => |tag_and_length| {
                if (next_tag_index) |tag_index| {
                     buf.index = tag_index;
                }
                try buf.add(tag_and_length.tag);
                if (tag_and_length.tag != TAG_LAST_SENTINEL) {
                    try buf.add(tag_and_length.length);
                    const TAG_REQUEST = 0;
                    try buf.add(TAG_REQUEST);
                    next_tag_index = buf.index + tag_and_length.length / 4;
                }
            },
            PropertiesStep.Get => {
            },
            PropertiesStep.In => |ptr| {
                try buf.add(ptr.*);
            },
            PropertiesStep.Set => |ptr| {
                try buf.add(ptr.*);
            },
        }
    }
    buffer_length_in_bytes = buf.index * 4;
    buf.reset();
    try buf.add(buffer_length_in_bytes);

    var buffer_pointer = @ptrToInt(buf.data.ptr);
    if (buffer_pointer & 0xF != 0) {
        panic(@errorReturnTrace(), "video core mailbox buffer not aligned to 16 bytes");
    }
    const PROPERTY_CHANNEL = 8;
    const request = PROPERTY_CHANNEL | @intCast(u32, buffer_pointer);
    mailboxes[1].pushRequestBlocking(request);
    try mailboxes[0].pullResponseBlocking(request);

    buf.reset();
    try check(&buf, buffer_length_in_bytes);
    const BUFFER_RESPONSE_OK = 0x80000000;
    try check(&buf, BUFFER_RESPONSE_OK);
    next_tag_index = null;
    for (codes) |code| {
        switch(code) {
            PropertiesStep.TagAndLength => |tag_and_length| {
                if (next_tag_index) |tag_index| {
                     buf.index = tag_index;
                }
                try check(&buf, tag_and_length.tag);
                if (tag_and_length.tag != TAG_LAST_SENTINEL) {
                    try check(&buf, tag_and_length.length);
                    const TAG_RESPONSE_OK = 0x80000000;
                    try check(&buf, TAG_RESPONSE_OK | tag_and_length.length);
                    next_tag_index = buf.index + tag_and_length.length / 4;
                }
            },
            PropertiesStep.Get => |ptr| {
                ptr.* = try buf.next();
            },
            PropertiesStep.In => {
            },
            PropertiesStep.Set => |ptr| {
                try check(&buf, ptr.*);
            },
        }
    }
}

fn check(buf: *SliceIterator.of(u32), word: u32) !void {
    const was = try buf.next();
    if (was != word) {
        return error.Failed;
    }
}

const assert = std.debug.assert;
const mailboxes = @import("video_core_mailboxes.zig").mailboxes;
const panic = @import("debug.zig").panic;
const SliceIterator = @import("slice_iterator.zig");
const std = @import("std");

const serial = @import("serial.zig");
fn log(comptime message: []const u8, args: ...) void {
    serial.log(message ++ "\n", args);
}
