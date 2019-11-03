pub const FrameBuffer = struct {
    alignment: u32,
    alpha_mode: u32,
    depth: u32,
    physical_width: u32,
    physical_height: u32,
    pitch: u32,
    pixel_order: u32,
    words: [*]volatile u32,
    size: u32,
    virtual_height: u32,
    virtual_width: u32,
    virtual_offset_x: u32,
    virtual_offset_y: u32,
    overscan_top: u32,
    overscan_bottom: u32,
    overscan_left: u32,
    overscan_right: u32,

    fn clear(fb: *FrameBuffer, color: Color) void {
        var y: u32 = 0;
        while (y < fb.virtual_height) : (y += 1) {
            var x: u32 = 0;
            while (x < fb.virtual_width) : (x += 1) {
                fb.drawPixel(x, y, color);
            }
        }
    }

    fn clearRect(fb: *FrameBuffer, x2: u32, y2: u32, width: u32, height: u32, color: Color) void {
        var y: u32 = 0;
        while (y < height) : (y += 1) {
            var x: u32 = 0;
            while (x < width) : (x += 1) {
                fb.drawPixel(x + x2, y + y2, color);
            }
        }
    }

    fn drawPixel(fb: *FrameBuffer, x: u32, y: u32, color: Color) void {
        assert(x < fb.virtual_width);
        assert(y < fb.virtual_height);
        const offset = y * fb.pitch + x;
        fb.drawPixel32(x, y, color.to32());
    }

    fn drawPixel32(fb: *FrameBuffer, x: u32, y: u32, color: u32) void {
        if (x >= fb.virtual_width or y >= fb.virtual_height) {
            panic(@errorReturnTrace(), "frame buffer index {}, {} does not fit in {}x{}", x, y, fb.virtual_width, fb.virtual_height);
        }
        fb.words[y * fb.pitch / 4 + x] = color;
    }

    pub fn init(fb: *FrameBuffer, metrics: *Metrics) void {
        var width: u32 = undefined;
        var height: u32 = undefined;
        if (metrics.is_qemu) {
            width = 1024;
            height = 768;
        } else {
            width = 1920;
            height = 1080;
        }
        fb.alignment = 256;
        fb.physical_width = width;
        fb.physical_height = height;
        fb.virtual_width = width;
        fb.virtual_height = height;
        fb.virtual_offset_x = 0;
        fb.virtual_offset_y = 0;
        fb.depth = 32;
        fb.pixel_order = 0;
        fb.alpha_mode = 0;

        var fb_addr: u32 = undefined;
        var arg = [_]PropertiesArg{
            tag(TAG_ALLOCATE_FRAME_BUFFER, 8),
            in(&fb.alignment),
            out(&fb_addr),
            out(&fb.size),
            tag(TAG_SET_DEPTH, 4),
            set(&fb.depth),
            tag(TAG_SET_PHYSICAL_WIDTH_HEIGHT, 8),
            set(&fb.physical_width),
            set(&fb.physical_height),
            tag(TAG_SET_PIXEL_ORDER, 4),
            set(&fb.pixel_order),
            tag(TAG_SET_VIRTUAL_WIDTH_HEIGHT, 8),
            set(&fb.virtual_width),
            set(&fb.virtual_height),
            tag(TAG_SET_VIRTUAL_OFFSET, 8),
            set(&fb.virtual_offset_x),
            set(&fb.virtual_offset_y),
            tag(TAG_SET_ALPHA_MODE, 4),
            set(&fb.alpha_mode),
            tag(TAG_GET_PITCH, 4),
            out(&fb.pitch),
            tag(TAG_GET_OVERSCAN, 16),
            out(&fb.overscan_top),
            out(&fb.overscan_bottom),
            out(&fb.overscan_left),
            out(&fb.overscan_right),
            last_tag_sentinel,
        };
        callVideoCoreProperties(&arg);

        fb.words = @intToPtr([*]volatile u32, fb_addr & 0x3FFFFFFF);
        log("fb align {} addr {x} alpha {} pitch {} order {} size {} physical {}x{} virtual {}x{} offset {},{} overscan t {} b {} l {} r {}", fb.alignment, @ptrToInt(fb.words), fb.alpha_mode, fb.pitch, fb.pixel_order, fb.size, fb.physical_width, fb.physical_height, fb.virtual_width, fb.virtual_height, fb.virtual_offset_x, fb.virtual_offset_y, fb.overscan_top, fb.overscan_bottom, fb.overscan_left, fb.overscan_right);
        if (@ptrToInt(fb.words) == 0) {
            panic(@errorReturnTrace(), "frame buffer pointer is zero");
        }
    }
};

pub const Bitmap = struct {
    frame_buffer: *FrameBuffer,
    pixel_array: [*]u8,
    width: u31,
    height: u31,

    fn getU32(base: [*]u8, offset: u32) u32 {
        var word: u32 = 0;
        var i: u32 = 0;
        while (i <= 3) : (i += 1) {
            word >>= 8;
            word |= @intCast(u32, @intToPtr(*u8, @ptrToInt(base) + offset + i).*) << 24;
        }
        return word;
    }

    pub fn init(bitmap: *Bitmap, frame_buffer: *FrameBuffer, file: []u8) void {
        bitmap.frame_buffer = frame_buffer;
        bitmap.pixel_array = @intToPtr([*]u8, @ptrToInt(file.ptr) + getU32(file.ptr, 0x0A));
        bitmap.width = @intCast(u31, getU32(file.ptr, 0x12));
        bitmap.height = @intCast(u31, getU32(file.ptr, 0x16));
    }

    fn getPixel(self: *Bitmap, x: u32, y: u32) Color {
        const rgba = getU32(self.pixel_array, ((self.height - 1 - y) * self.width + x) * @sizeOf(u32));
        return Color{
            .red = @intCast(u8, (rgba >> 16) & 0xff),
            .green = @intCast(u8, (rgba >> 8) & 0xff),
            .blue = @intCast(u8, (rgba >> 0) & 0xff),
            .alpha = @intCast(u8, (rgba >> 24) & 0xff),
        };
    }

    fn drawRect(self: *Bitmap, width: u32, height: u32, x1: u32, y1: u32, x2: u32, y2: u32) void {
        var y: u32 = 0;
        while (y < height) : (y += 1) {
            var x: u32 = 0;
            while (x < width) : (x += 1) {
                self.frame_buffer.drawPixel(x + x2, y + y2, self.getPixel(x + x1, y + y1));
            }
        }
    }
};

const TAG_ALLOCATE_FRAME_BUFFER = 0x40001;

const TAG_GET_OVERSCAN = 0x4000A;
const TAG_GET_PITCH = 0x40008;

const TAG_SET_ALPHA_MODE = 0x48007;
const TAG_SET_DEPTH = 0x48005;
const TAG_SET_PHYSICAL_WIDTH_HEIGHT = 0x48003;
const TAG_SET_PIXEL_ORDER = 0x48006;
const TAG_SET_VIRTUAL_OFFSET = 0x48009;
const TAG_SET_VIRTUAL_WIDTH_HEIGHT = 0x48004;

pub const Color = struct {
    red: u8,
    green: u8,
    blue: u8,
    alpha: u8,

    fn to32(color: Color) u32 {
        return (255 - @intCast(u32, color.alpha) << 24) | @intCast(u32, color.red) << 16 | @intCast(u32, color.green) << 8 | @intCast(u32, color.blue) << 0;
    }
};

const log = @import("serial.zig").log;
const Metrics = @import("video_core_metrics.zig").Metrics;
const panic = @import("debug.zig").panic;
usingnamespace @import("video_core_properties.zig");
const std = @import("std");
const assert = std.debug.assert;
