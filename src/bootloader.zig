// The bootloader is a separate executable, the hardware does not boot
// directly into it. When the kernel wants to load a new image from the
// serial port, it copies the bootloader executable code into memory at
// address bootloader_address which matches the linker script for the bootloader
// executable. Then the kernel jumps to bootloader_address. The bootloader then
// overwrites the kernel's code, which is why a separate bootloader
// executable is necessary.
const std = @import("std");
const builtin = @import("builtin");
const debug = @import("debug.zig");
const serial = @import("serial.zig");

export fn bootloaderMain(start_addr: [*]u8, len: usize) linksection(".text.first") noreturn {
    var i: usize = 0;
    while (i < len) : (i += 1) {
        start_addr[i] = serial.readByte();
    }

    serial.log("Jumping to new code...\n", .{});
    while (!serial.isDoneWriting()) {}
    asm volatile (
        \\ mov sp,#0x08000000
        \\ eor x29, x29, x29
        \\ eor x30, x30, x30
        \\ b kernel_main
    );
    unreachable;
}

pub fn panic(message: []const u8, stack_trace: ?*builtin.StackTrace) noreturn {
    serial.log("BOOTLOADER PANIC: {}", .{message});
    debug.wfeHang();
}
