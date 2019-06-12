const std = @import("std");
const serial = @import("serial.zig");
const builtin = @import("builtin");
const debug = @import("debug.zig");
const FrameBuffer = @import("video_core_frame_buffer.zig").FrameBuffer;
const Color = @import("video_core_frame_buffer.zig").Color;

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
        \\ bl kernel_main
        \\hang:
        \\ wfe
        \\ b hang
    );
}

pub fn panic(message: []const u8, stack_trace: ?*builtin.StackTrace) noreturn {
    debug.panic(stack_trace, "KERNEL PANIC: {}", message);
}

export fn kernel_main() linksection(".text.main") noreturn {
    // clear .bss
    @memset((*volatile [1]u8)(&__bss_start), 0, @ptrToInt(&__bss_end) - @ptrToInt(&__bss_start));

    serial.init();
    serial.log("ClashOS 0.0\n");

    cntfrq = asm("mrs %[cntfrq], cntfrq_el0" : [cntfrq] "=r" (-> usize));
    cntfrq_f32 = @intToFloat(f32, cntfrq);

    updateTime();

    fb = FrameBuffer.init(800, 600) catch |err| debug.panic(@errorReturnTrace(), "{} frame buffer initialization", err);
    fb.clear(&color_yellow);

    serialLoop();
}

var fb: FrameBuffer = undefined;

const build_options = @import("build_options");
const bootloader_code align(@alignOf(std.elf.Elf64_Ehdr)) = @embedFile("../" ++ build_options.bootloader_exe_path);

fn serialLoop() noreturn {
    const boot_magic = [_]u8{ 6, 6, 6 };
    var boot_magic_index: usize = 0;
    var color = color_yellow;
    var x: usize = 0;
    var y: usize = 0;
    while (true) {
        if (!serial.isReadByteReady()) {
            fb.drawPixel(x, y, color);
            x = x + 1;
            if (x == fb.virtual_width) {
                x = 0;
                y = y + 1;
                if (y == fb.virtual_height) {
                    y = 0;
                }
                const delta = 10;
                color.red = color.red +% delta;
                if (color.red < delta) {
                    color.green = color.green +% delta;
                    if (color.green < delta) {
                        color.blue = color.blue +% delta;
                    }
                }
            }
            continue;
        }
        const byte = serial.readByte();
        if (byte == boot_magic[boot_magic_index]) {
            boot_magic_index += 1;
            if (boot_magic_index != boot_magic.len)
                continue;

            // It's time to receive the new kernel. First
            // we skip over the .text.boot bytes, verifying that they
            // are unchanged.
            const new_kernel_len = serial.in.readIntLittle(u32) catch unreachable;
            serial.log("New kernel image detected, {Bi2}\n", new_kernel_len);
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
            const start_addr = @ptrToInt(kernel_main);
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
            serial.log("Loading new image...\n");
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
}

var cntfrq: usize = undefined;
var cntfrq_f32: f32 = undefined;
var cntpct: usize = undefined;
var seconds: f32 = undefined;

fn updateTime () void {
    cntpct = asm("mrs %[cntpct], cntpct_el0" : [cntpct] "=r" (-> usize));
    seconds = @intToFloat(f32, cntpct) / cntfrq_f32;
    serial.log("time {}\n", seconds);
}

const color_red = Color{ .red = 255, .green = 0, .blue = 0, .alpha = 255 };
const color_green = Color{ .red = 0, .green = 255, .blue = 0, .alpha = 255 };
const color_blue = Color{ .red = 0, .green = 0, .blue = 255, .alpha = 255 };
const color_yellow = Color{ .red = 255, .green = 255, .blue = 0, .alpha = 255 };
