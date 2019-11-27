const builtin = @import("builtin");
const Bitmap = @import("video_core_frame_buffer.zig").Bitmap;
const Color = @import("video_core_frame_buffer.zig").Color;
const debug = @import("debug.zig");
const FrameBuffer = @import("video_core_frame_buffer.zig").FrameBuffer;
const Metrics = @import("video_core_metrics.zig").Metrics;
const serial = @import("serial.zig");
const time = @import("time.zig");
const std = @import("std");
const exceptions = @import("exceptions.zig");

// The linker will make the address of these global variables equal
// to the value we are interested in. The memory at the address
// could alias any uninitialized global variable in the kernel.
extern var __bss_start: u8;
extern var __bss_end: u8;
extern var __end_init: u8;

extern fn bootloaderMain(start_addr: [*]u8, len: usize) noreturn;

comptime {
    // .text.boot to keep this in the first portion of the binary
    // Note: this code cannot be changed via the bootloader.
    asm (
        \\.section .text.boot
        \\.globl _start
        \\_start:
        \\ mrs x0,mpidr_el1
        \\ mov x1,#0xC1000000
        \\ bic x0,x0,x1
        \\ cbz x0,master
        \\ b hang
        \\master:
        \\ mov sp,#0x08000000
        \\ eor x29, x29, x29  /* zero the link register for correct stacktraces */
        \\ eor x30, x30, x30
        \\ b kernelMain
        \\hang:
        \\ wfe
        \\ b hang
    );
}

pub fn panic(message: []const u8, trace: ?*builtin.StackTrace) noreturn {
    debug.panic(trace, "KERNEL PANIC: {}", .{message});
}

export fn kernelMain() linksection(".text.main") noreturn {
    // clear .bss
    @memset(@as(*volatile [1]u8, &__bss_start), 0, @ptrToInt(&__bss_end) - @ptrToInt(&__bss_start));

    exceptions.init();
    serial.init();

    clashosMain(); // shouldn't return but if it does hang
    debug.wfeHang();
}

fn clashosMain() void {
    serial.log("\n{} {} ...\n", .{ name, version });

    // time.init();
    // metrics.init();

    // fb.init(&metrics);
    // icon.init(&fb, &logo_bmp_file);
    // logo.init(&fb, &logo_bmp_file);

    // screen_activity.init();
    serial_activity.init();

    while (true) {
        // screen_activity.update();
        serial_activity.update();
    }
}

const ScreenActivity = struct {
    height: u32,
    color: Color,
    color32: u32,
    top: u32,
    x: i32,
    y: i32,
    vel_x: i32,
    vel_y: i32,
    ref_seconds: f32,
    pixel_counter: u32,

    fn init(self: *ScreenActivity) void {
        self.color = color_yellow;
        self.color32 = self.color.to32();
        self.height = logo.height;
        self.top = logo.height + margin;
        self.x = 0;
        self.y = 0;
        self.vel_x = 10;
        self.vel_y = 10;
        time.update();
        self.ref_seconds = time.seconds;
        self.pixel_counter = 0;
    }

    fn update(self: *ScreenActivity) void {
        time.update();
        const new_ref_secs = self.ref_seconds + 0.05;
        if (time.seconds >= new_ref_secs) {
            const clear_x = @intCast(u32, self.x);
            const clear_y = @intCast(u32, self.y);
            fb.clearRect(clear_x, clear_y, logo.width, logo.height, color_black);

            self.ref_seconds = new_ref_secs;
            self.x += self.vel_x;
            self.y += self.vel_y;

            if (self.x + @as(i32, logo.width) >= @intCast(i32, fb.virtual_width)) {
                self.x = @intCast(i32, fb.virtual_width - logo.width);
                self.vel_x = -self.vel_x;
            }
            if (self.y + @as(i32, logo.height) >= @intCast(i32, fb.virtual_height)) {
                self.y = @intCast(i32, fb.virtual_height - logo.height);
                self.vel_y = -self.vel_y;
            }
            if (self.x < 0) {
                self.x = 0;
                self.vel_x = -self.vel_x;
            }
            if (self.y < 0) {
                self.y = 0;
                self.vel_y = -self.vel_y;
            }
            const draw_x = @intCast(u32, self.x);
            const draw_y = @intCast(u32, self.y);
            logo.drawRect(logo.width, logo.height, 0, 0, draw_x, draw_y);
        }
    }
};

const SerialActivity = struct {
    boot_magic_index: usize,

    fn init(self: *SerialActivity) void {
        self.boot_magic_index = 0;
        serial.log("now echoing input on uart1...\n", .{});
    }

    fn update(self: *SerialActivity) void {
        if (!serial.isReadByteReady()) {
            return;
        }
        const boot_magic = [_]u8{ 6, 6, 6 };
        const byte = serial.readByte();
        if (byte == boot_magic[self.boot_magic_index]) {
            self.boot_magic_index += 1;
            if (self.boot_magic_index != boot_magic.len)
                return;

            // First we copy the bootloader code to the correct memory address,
            // such that we can jump to it, when the new kernel is received.
            var bootloader_code_ptr = @as([*]const u8, &bootloader_code); // TODO remove workaround `var`
            const dest_ptr = @intToPtr([*]u8, 0x8800000);
            @memcpy(dest_ptr, bootloader_code_ptr, bootloader_code.len);

            // It's time to receive the new kernel. First
            // we skip over the .text.boot bytes, verifying that they
            // are unchanged.
            const new_kernel_len = serial.in.readIntLittle(u32) catch unreachable;
            serial.log("New kernel image detected, {Bi:2}\n", .{new_kernel_len});

            const text_boot_len = @ptrToInt(&__end_init) - 0x80000;
            const text_boot = @intToPtr([*]const u8, 0x80000)[0..text_boot_len];
            for (text_boot) |text_boot_byte, byte_index| {
                const new_byte = serial.readByte();
                if (new_byte != text_boot_byte) {
                    debug.panic(@errorReturnTrace(), "new_kernel[{}] expected: 0x{x} actual: 0x{x}", .{
                        byte_index,
                        text_boot_byte,
                        new_byte,
                    });
                }
            }
            const start_addr = @ptrToInt(kernelMain);

            // Skip over the padding and jump to the bootloader code
            const padding_start_addr = start_addr - 0x80000;
            const bytes_left = new_kernel_len - padding_start_addr;
            var pad = padding_start_addr - text_boot.len;
            while (pad > 0) : (pad -= 1) {
                _ = serial.readByte();
            }

            bootloaderMain(@intToPtr([*]u8, start_addr), bytes_left);
        }
        switch (byte) {
            '\r' => {
                serial.writeText("\n");
            },
            else => serial.writeByte(byte),
        }
    }
};

const build_options = @import("build_options");
const bootloader_code align(@alignOf(u32)) = @embedFile("../" ++ build_options.bootloader_exe_path).*;

var screen_activity: ScreenActivity = undefined;
var serial_activity: SerialActivity = undefined;
var fb: FrameBuffer = undefined;
var metrics: Metrics = undefined;
var icon: Bitmap = undefined;
var logo: Bitmap = undefined;

var icon_bmp_file align(@alignOf(u32)) = @embedFile("../assets/zig-icon.bmp").*;
var logo_bmp_file align(@alignOf(u32)) = @embedFile("../assets/zig-logo.bmp").*;

const margin = 10;

const color_red = Color{ .red = 255, .green = 0, .blue = 0, .alpha = 255 };
const color_green = Color{ .red = 0, .green = 255, .blue = 0, .alpha = 255 };
const color_blue = Color{ .red = 0, .green = 0, .blue = 255, .alpha = 255 };
const color_yellow = Color{ .red = 255, .green = 255, .blue = 0, .alpha = 255 };
const color_white = Color{ .red = 255, .green = 255, .blue = 255, .alpha = 255 };
const color_black = Color{ .red = 0, .green = 0, .blue = 0, .alpha = 255 };

const name = "ClashOS";
const version = "0.3";
