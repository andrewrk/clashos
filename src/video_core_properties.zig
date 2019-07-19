pub fn callVideoCoreProperties(args: []PropertiesArg) void {
    if(args[args.len - 1].TagAndLength.tag != TAG_LAST_SENTINEL) {
        panic(@errorReturnTrace(), "video core mailbox buffer missing last tag sentinel");
    }

    var words: [512]u32 align(16) = undefined;
    var buf = SliceIterator.of(u32).init(&words);

    var buffer_length_in_bytes: u32 = 0;
    buf.add(buffer_length_in_bytes);
    const BUFFER_REQUEST = 0;
    buf.add(BUFFER_REQUEST);
    var next_tag_index = buf.index;
    for (args) |arg| {
        switch(arg) {
            PropertiesArg.TagAndLength => |tag_and_length| {
                if (tag_and_length.tag != 0) {
//                  log("prepare tag {x} length {}", tag_and_length.tag, tag_and_length.length);
                }
                buf.index = next_tag_index;
                buf.add(tag_and_length.tag);
                if (tag_and_length.tag != TAG_LAST_SENTINEL) {
                    buf.add(tag_and_length.length);
                    const TAG_REQUEST = 0;
                    buf.add(TAG_REQUEST);
                    next_tag_index = buf.index + tag_and_length.length / 4;
                }
            },
            PropertiesArg.Out => {
            },
            PropertiesArg.In => |ptr| {
                buf.add(ptr.*);
            },
            PropertiesArg.Set => |ptr| {
                buf.add(ptr.*);
            },
        }
    }
    buffer_length_in_bytes = buf.index * 4;
    buf.reset();
    buf.add(buffer_length_in_bytes);

    var buffer_pointer = @ptrToInt(buf.data.ptr);
    if (buffer_pointer & 0xF != 0) {
        panic(@errorReturnTrace(), "video core mailbox buffer not aligned to 16 bytes");
    }
    const PROPERTY_CHANNEL = 8;
    const request = PROPERTY_CHANNEL | @intCast(u32, buffer_pointer);
    mailboxes[1].pushRequestBlocking(request);
//  log("pull mailbox response");
    mailboxes[0].pullResponseBlocking(request);

    buf.reset();
    check(&buf, buffer_length_in_bytes);
    const BUFFER_RESPONSE_OK = 0x80000000;
    check(&buf, BUFFER_RESPONSE_OK);
    next_tag_index = buf.index;
    for (args) |arg| {
        switch(arg) {
            PropertiesArg.TagAndLength => |tag_and_length| {
                if (tag_and_length.tag != 0) {
//                  log("parse   tag {x} length {}", tag_and_length.tag, tag_and_length.length);
                }
                buf.index = next_tag_index;
                check(&buf, tag_and_length.tag);
                if (tag_and_length.tag != TAG_LAST_SENTINEL) {
                    check(&buf, tag_and_length.length);
                    const TAG_RESPONSE_OK = 0x80000000;
                    check(&buf, TAG_RESPONSE_OK | tag_and_length.length);
                    next_tag_index = buf.index + tag_and_length.length / 4;
                }
            },
            PropertiesArg.Out => |ptr| {
                ptr.* = buf.next();
            },
            PropertiesArg.In => {
            },
            PropertiesArg.Set => |ptr| {
                check(&buf, ptr.*);
            },
        }
    }
//  log("properties done");
}

pub fn out(ptr: *u32) PropertiesArg {
    return PropertiesArg{ .Out = ptr };
}

pub fn in(ptr: *u32) PropertiesArg {
    return PropertiesArg{ .In = ptr };
}

const TAG_LAST_SENTINEL = 0;
pub fn lastTagSentinel() PropertiesArg {
    return tag(TAG_LAST_SENTINEL, 0);
}

pub fn set(ptr: *u32) PropertiesArg {
    return PropertiesArg{ .Set = ptr };
}

pub fn tag(the_tag: u32, length: u32) PropertiesArg {
    return PropertiesArg{ .TagAndLength = TagAndLength{ .tag = the_tag, .length = length } };
}

pub const PropertiesArg = union(enum) {
    In: *u32,
    Out: *u32,
    Set: *u32,
    TagAndLength: TagAndLength,
};

const TagAndLength = struct {
    tag: u32,
    length: u32,
};

fn check(buf: *SliceIterator.of(u32), word: u32) void {
    const was = buf.next();
    if (was != word) {
        panic(@errorReturnTrace(), "video core mailbox failed index {} was {}/{x} expected {}/{x}", buf.index - 1, was, was, word, word);
    }
}

const assert = std.debug.assert;
//const log = @import("serial.zig").log;
const mailboxes = @import("video_core_mailboxes.zig").mailboxes;
const panic = @import("debug.zig").panic;
const SliceIterator = @import("slice_iterator.zig");
const std = @import("std");
