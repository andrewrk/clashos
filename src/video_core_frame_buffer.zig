pub const FrameBuffer = struct {
    alignment: u32,
    alpha_mode: u32,
    depth: u32,
    physical_width: u32,
    physical_height: u32,
    pitch: u32,
    pixel_order: u32,
    ptr: [*]volatile u8,
    size: u32,
    virtual_height: u32,
    virtual_width: u32,
    virtual_offset_x: u32,
    virtual_offset_y: u32,

    fn clear(fb: FrameBuffer, color: *const Color) void {
        var y: usize = 0;
        while (y < fb.virtual_height) : (y += 1) {
            var x: usize = 0;
            while (x < fb.virtual_width) : (x += 1) {
                const offset = y * fb.pitch + x * 4;
                fb.ptr[offset] = color.red;
                fb.ptr[offset + 1] = color.green;
                fb.ptr[offset + 2] = color.blue;
                fb.ptr[offset + 3] = color.alpha;
            }
        }
    }

    fn drawPixel(fb: *FrameBuffer, x: usize, y: usize, color: Color) void {
        if (x >= fb.virtual_width or y >= fb.virtual_height) {
            panic(@errorReturnTrace(), "frame buffer bounds");
        }
        const offset = y * fb.pitch + x * 4;
        fb.ptr[offset] = color.red;
        fb.ptr[offset + 1] = color.green;
        fb.ptr[offset + 2] = color.blue;
        fb.ptr[offset + 3] = color.alpha;
    }

    pub fn init(width: u32, height: u32) !FrameBuffer {
        var fb: FrameBuffer = undefined;
        fb.alignment = 256;
        fb.physical_width = width;
        fb.physical_height = height;
        fb.virtual_width = width;
        fb.virtual_height = height;
        fb.virtual_offset_x = 0;
        fb.virtual_offset_y = 0;
        fb.depth = 32;
        fb.pixel_order = 1;
        fb.alpha_mode = 1;

        try callVideoCoreProperties(&[_]PropertiesStep{
            tag(TAG_ALLOCATE_FRAME_BUFFER, 8),
            in(&fb.alignment),
            get(@ptrCast(*u32, &fb.ptr)),
            get(&fb.size),
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
            get(&fb.pitch),
            lastTagSentinel(),
        });

        fb.ptr = @intToPtr([*]volatile u8, @ptrToInt(fb.ptr) & 0x3FFFFFFF);
        return fb;
    }
};

const TAG_ALLOCATE_FRAME_BUFFER = 0x40001;

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
};

const panic = @import("debug.zig").panic;
use @import("video_core_properties.zig");
