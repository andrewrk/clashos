const builtin = @import("builtin");
const Bitmap = @import("video_core_frame_buffer.zig").Bitmap;
const Color = @import("video_core_frame_buffer.zig").Color;
const debug = @import("debug.zig");
const FrameBuffer = @import("video_core_frame_buffer.zig").FrameBuffer;
const Metrics = @import("video_core_metrics.zig").Metrics;
const serial = @import("serial.zig");
const time = @import("time.zig");
const std = @import("std");

// The linker will make the address of these global variables equal
// to the value we are interested in. The memory at the address
// could alias any uninitialized global variable in the kernel.
extern var __bss_start: u8;
extern var __bss_end: u8;
extern var __end_init: u8;

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
        \\ mov x0,#0x800 //exception_vector_table
        \\ msr vbar_el3,x0
        \\ msr vbar_el2,x0
        \\ msr vbar_el1,x0
        \\ bl kernelMainAt0x1100
        \\hang:
        \\ wfe
        \\ b hang
        \\exception_vector_table:
        \\.balign 0x800
        \\.balign 0x80
        \\ b shortExceptionHandlerAt0x1000
        \\.balign 0x80
        \\ b shortExceptionHandlerAt0x1000
        \\.balign 0x80
        \\ b shortExceptionHandlerAt0x1000
        \\.balign 0x80
        \\ b shortExceptionHandlerAt0x1000
        \\.balign 0x80
        \\ b shortExceptionHandlerAt0x1000
        \\.balign 0x80
        \\ b shortExceptionHandlerAt0x1000
        \\.balign 0x80
        \\ b shortExceptionHandlerAt0x1000
        \\.balign 0x80
        \\ b shortExceptionHandlerAt0x1000
        \\.balign 0x80
        \\ b shortExceptionHandlerAt0x1000
        \\.balign 0x80
        \\ b shortExceptionHandlerAt0x1000
        \\.balign 0x80
        \\ b shortExceptionHandlerAt0x1000
        \\.balign 0x80
        \\ b shortExceptionHandlerAt0x1000
        \\.balign 0x80
        \\ b shortExceptionHandlerAt0x1000
        \\.balign 0x80
        \\ b shortExceptionHandlerAt0x1000
        \\.balign 0x80
        \\ b shortExceptionHandlerAt0x1000
        \\.balign 0x80
        \\ b shortExceptionHandlerAt0x1000
    );
}

export fn shortExceptionHandlerAt0x1000() linksection(".text.exception") void {
    exceptionHandler();
}

pub fn panic(message: []const u8, trace: ?*builtin.StackTrace) noreturn {
    debug.panic(trace, "KERNEL PANIC: {}", message);
}

fn exceptionHandler() void {
    serial.log("arm exception taken");
    var current_el = asm ("mrs %[current_el], CurrentEL"
        : [current_el] "=r" (-> usize)
    );
    serial.log("CurrentEL {x} exception level {}", current_el, current_el >> 2 & 0x3);
    var esr_el3 = asm ("mrs %[esr_el3], esr_el3"
        : [esr_el3] "=r" (-> usize)
    );
    serial.log("esr_el3 {x} code 0x{x}", esr_el3, esr_el3 >> 26 & 0x3f);
    var elr_el3 = asm ("mrs %[elr_el3], elr_el3"
        : [elr_el3] "=r" (-> usize)
    );
    serial.log("elr_el3 {x}", elr_el3);
    var spsr_el3 = asm ("mrs %[spsr_el3], spsr_el3"
        : [spsr_el3] "=r" (-> usize)
    );
    serial.log("spsr_el3 {x}", spsr_el3);
    var far_el3 = asm ("mrs %[far_el3], far_el3"
        : [far_el3] "=r" (-> usize)
    );
    serial.log("far_el3 {x}", far_el3);
    serial.log("execution is now stopped in arm exception handler");
    while (true) {
        asm volatile ("wfe");
    }
}

export fn kernelMainAt0x1100() linksection(".text.main") noreturn {
    // clear .bss
    @memset((*volatile [1]u8)(&__bss_start), 0, @ptrToInt(&__bss_end) - @ptrToInt(&__bss_start));

    serial.init();
    serial.log("\n{} {} ...", name, version);

    time.init();
    metrics.init();

    fb.init(&metrics);
    icon.init(&fb, &logo_bmp_file);
    logo.init(&fb, &logo_bmp_file);
    logo.drawRect(logo.width, logo.height, 0, 0, 0, 0);

    screen_activity.init();
    serial_activity.init();

    while (true) {
        screen_activity.update();
        serial_activity.update();
    }
}

const ScreenActivity = struct {
    height: u32,
    color: Color,
    color32: u32,
    top: u32,
    x: u32,
    y: u32,
    ref_seconds: f32,
    pixel_counter: u32,

    fn init(self: *ScreenActivity) void {
        self.color = color_yellow;
        self.color32 = fb.color32(self.color);
        self.height = logo.height;
        self.top = logo.height + margin;
        self.x = 0;
        self.y = self.top;
        time.update();
        self.ref_seconds = time.seconds;
        self.pixel_counter = 0;
    }

    fn update(self: *ScreenActivity) void {
        fb.drawPixel32(self.x, self.y, self.color32);
        self.x += 1;
        self.pixel_counter += 1;
        if (self.x == logo.width) {
            time.update();
            if (time.seconds >= self.ref_seconds + 1.0) {
                //              serial.log("{} pixels per second", self.pixel_counter);
                self.pixel_counter = 0;
                self.ref_seconds += 1.0;
            }
            self.x = 0;
            self.y += 1;
            if (self.y == self.top + self.height) {
                self.y = self.top;
            }
            const delta = 10;
            self.color.red = self.color.red +% delta;
            if (self.color.red < delta) {
                self.color.green = self.color.green +% delta;
                if (self.color.green < delta) {
                    self.color.blue = self.color.blue +% delta;
                }
            }
            self.color32 = fb.color32(self.color);
        }
    }
};

const SerialActivity = struct {
    boot_magic_index: usize,

    fn init(self: *SerialActivity) void {
        self.boot_magic_index = 0;
        serial.log("now echoing input on uart1 ...");
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

            // It's time to receive the new kernel. First
            // we skip over the .text.boot bytes, verifying that they
            // are unchanged.
            const new_kernel_len = serial.in.readIntLittle(u32) catch unreachable;
            serial.log("New kernel image detected, {Bi:2}", new_kernel_len);
            const text_boot = @intToPtr([*]allowzero const u8, 0)[0..@ptrToInt(&__end_init)];
            for (text_boot) |text_boot_byte, byte_index| {
                const new_byte = serial.readByte();
                if (new_byte != text_boot_byte) {
                    debug.panic(
                        @errorReturnTrace(),
                        "new_kernel[{}] expected: 0x{x} actual: 0x{x}",
                        byte_index,
                        text_boot_byte,
                        new_byte,
                    );
                }
            }
            const start_addr = @ptrToInt(shortExceptionHandlerAt0x1000);
            const bytes_left = new_kernel_len - start_addr;
            var pad = start_addr - text_boot.len;
            while (pad > 0) : (pad -= 1) {
                _ = serial.readByte();
            }

            // Next we copy the bootloader code to the correct memory address,
            // and then jump to it.
            // Read the ELF
            var bootloader_code_ptr = ([*]const u8)(&bootloader_code); // TODO remove workaround `var`
            const ehdr = @ptrCast(*const std.elf.Elf64_Ehdr, bootloader_code_ptr);
            var phdr_addr = bootloader_code_ptr + ehdr.e_phoff;
            var phdr_i: usize = 0;
            while (phdr_i < ehdr.e_phnum) : ({
                phdr_i += 1;
                phdr_addr += ehdr.e_phentsize;
            }) {
                const this_ph = @ptrCast(*const std.elf.Elf64_Phdr, phdr_addr);
                switch (this_ph.p_type) {
                    std.elf.PT_LOAD => {
                        const src_ptr = bootloader_code_ptr + this_ph.p_offset;
                        const src_len = this_ph.p_filesz;
                        const dest_ptr = @intToPtr([*]u8, this_ph.p_vaddr);
                        const dest_len = this_ph.p_memsz;
                        const pad_len = dest_len - src_len;
                        const copy_len = dest_len - pad_len;
                        @memcpy(dest_ptr, src_ptr, copy_len);
                        @memset(dest_ptr + copy_len, 0, pad_len);
                    },
                    std.elf.PT_GNU_STACK => {}, // ignore
                    else => debug.panic(
                        @errorReturnTrace(),
                        "unexpected ELF Program Header load type: {}",
                        this_ph.p_type,
                    ),
                }
            }
            serial.log("Loading new image...");
            asm volatile (
                \\mov sp,#0x08000000
                \\bl bootloader_main
                :
                : [arg0] "{x0}" (start_addr),
                  [arg1] "{x1}" (bytes_left)
            );
            unreachable;
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
const bootloader_code align(@alignOf(std.elf.Elf64_Ehdr)) = @embedFile("../" ++ build_options.bootloader_exe_path);

var screen_activity: ScreenActivity = undefined;
var serial_activity: SerialActivity = undefined;
var fb: FrameBuffer = undefined;
var metrics: Metrics = undefined;
var icon: Bitmap = undefined;
var logo: Bitmap = undefined;

var icon_bmp_file align(@alignOf(u32)) = @embedFile("../assets/zig-icon.bmp");
var logo_bmp_file align(@alignOf(u32)) = @embedFile("../assets/zig-logo.bmp");

const margin = 10;

const color_red = Color{ .red = 255, .green = 0, .blue = 0, .alpha = 255 };
const color_green = Color{ .red = 0, .green = 255, .blue = 0, .alpha = 255 };
const color_blue = Color{ .red = 0, .green = 0, .blue = 255, .alpha = 255 };
const color_yellow = Color{ .red = 255, .green = 255, .blue = 0, .alpha = 255 };
const color_white = Color{ .red = 255, .green = 255, .blue = 255, .alpha = 255 };

const name = "ClashOS";
const version = "0.2";
