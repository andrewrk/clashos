const std = @import("std");
const assert = std.debug.assert;
const serial = @import("serial.zig");
const mmio = @import("mmio.zig");
const builtin = @import("builtin");
const AtomicOrder = builtin.AtomicOrder;
const debug = @import("debug.zig");

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

    //while (true) {
    //    if (fb_init()) {
    //        break;
    //    } else |_| {
    //        panic("Unable to initialize framebuffer", null);
    //    }
    //}

    //serial.log("Screen size: {}x{}\n", fb_info.width, fb_info.height);

    //fb_clear(&color_blue);

    serialLoop();
}

const build_options = @import("build_options");
const bootloader_code align(@alignOf(std.elf.Elf64_Ehdr)) = @embedFile("../" ++ build_options.bootloader_exe_path);

fn serialLoop() noreturn {
    const boot_magic = []u8{ 6, 6, 6 };
    var boot_magic_index: usize = 0;
    while (true) {
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

const color_red = Color{ .red = 255, .green = 0, .blue = 0 };
const color_green = Color{ .red = 0, .green = 255, .blue = 0 };
const color_blue = Color{ .red = 0, .green = 0, .blue = 255 };

var fb_info: FbInfo = undefined;

const FbInfo = struct {
    // Stuff about the pixel frame buffer
    width: usize,
    height: usize,
    pitch: usize, //BCM2836 has this separate, so we use this instead of witdh
    ptr: [*]volatile u8,
    size: usize,
};

const Bcm2836FrameBuffer = packed struct {
    width: usize, // Width of the frame buffer (pixels)
    height: usize, // Height of the frame buffer
    vwidth: usize, // Simplest thing to do is to set vwidth = width
    vheight: usize, // Simplest thing to do is to set vheight = height
    pitch: usize, // GPU fills this in, set to zero
    depth: usize, // Bits per pixel, set to 24
    x: usize, // Offset in x direction. Simplest thing to do is set to zero
    y: usize, // Offset in y direction. Simplest thing to do is set to zero
    pointer: usize, // GPU fills this in to be a pointer to the frame buffer
    size: usize, // GPU fills this in
};

fn fb_init() error{}!void {
    //serial.log("Initializing USB...\n");
    //%%usb.init();
    serial.log("Initializing frame buffer...\n");

    // We need to put the frame buffer structure somewhere with the lower 4 bits zero.
    // 0x400000 is a convenient place not used by anything, and with sufficient alignment
    const fb = @intToPtr(*volatile Bcm2836FrameBuffer, 0x400000);

    const width = 800;
    const height = 600;

    @fence(AtomicOrder.SeqCst);
    fb.width = width;
    fb.height = height;
    fb.vwidth = width;
    fb.vheight = height;
    fb.pitch = 0;
    fb.depth = 24;
    fb.x = 0;
    fb.y = 0;
    fb.pointer = 0;
    fb.size = 0;

    //// Tell the GPU the address of the structure
    //mbox_write(ArmToVc(@ptrToInt(fb)));

    //// Wait for the GPU to respond, and get its response
    //const response = mbox_read();
    //if (response != 0) return error.NonZeroFrameBufferResponse;
    //if (fb.pointer == 0) return error.NullFrameBufferPointer;

    //fb_info.ptr = @intToPtr([*]u8, VcToArm(fb.pointer));
    //fb_info.size = fb.size;
    //fb_info.width = fb.width;
    //fb_info.height = fb.height;
    //fb_info.pitch = fb.pitch;
}

fn fb_clear(color: *const Color) void {
    {
        var y: usize = 0;
        while (y < fb_info.height) : (y += 1) {
            {
                var x: usize = 0;
                while (x < fb_info.width) : (x += 1) {
                    const offset = y * fb_info.pitch + x * 3;
                    fb_info.ptr[offset] = color.red;
                    fb_info.ptr[offset + 1] = color.green;
                    fb_info.ptr[offset + 2] = color.blue;
                }
            }
        }
    }
    @fence(AtomicOrder.SeqCst);
}

const Color = struct {
    red: u8,
    green: u8,
    blue: u8,
};

const PERIPHERAL_BASE = 0x3F000000; // Base address for all peripherals

// This is the base address for the mailbox registers
// Actually, there's more than one mailbox, but this is the one we care about.
const MAIL_BASE = PERIPHERAL_BASE + 0xB880;

// Registers from mailbox 0 that we use
const MAIL_READ = MAIL_BASE + 0x00; // We read from this register
const MAIL_WRITE = MAIL_BASE + 0x20; // This is where we write to; it is actually the read/write of the other mailbox
const MAIL_STATUS = MAIL_BASE + 0x18; // Status register for this mailbox
const MAIL_CONFIG = MAIL_BASE + 0x1C; // we don't actually use this, but it exists

// This bit is set in the status register if there is no space to write into the mailbox
const MAIL_FULL = 0x80000000;
// This bit is set if there is nothing to read from the mailbox
const MAIL_EMPTY = 0x40000000;

const MAIL_FB = 1; // The frame buffer uses channel 1

fn mbox_write(v: u32) void {
    // wait for space
    while (mmio.read(MAIL_STATUS) & MAIL_FULL != 0) {}
    // Write the value to the frame buffer channel
    mmio.write(MAIL_WRITE, MAIL_FB | (v & 0xFFFFFFF0));
}

fn mbox_read() u32 {
    while (true) {
        // wait for data
        while (mmio.read(MAIL_STATUS) & MAIL_EMPTY != 0) {}
        const result = mmio.read(MAIL_READ);

        // Loop until we received something from the
        // frame buffer channel
        if ((result & 0xf) == MAIL_FB)
            return result & 0xFFFFFFF0;
    }
}

fn ArmToVc(addr: usize) usize {
    // Some things (e.g: the GPU) expect bus addresses, not ARM physical
    // addresses
    return addr + 0xC0000000;
}

fn VcToArm(addr: usize) usize {
    // Go the other way to ArmToVc
    return addr - 0xC0000000;
}
