const std = @import("std");
const io = std.io;
const assert = std.debug.assert;

// The linker will make the address of these global variables equal
// to the value we are interested in. The memory at the address
// could alias any uninitialized global variable in the kernel.
extern var __bss_start: u8;
extern var __bss_end: u8;

// r0 -> 0x00000000
// r1 -> 0x00000C42
// r2 -> 0x00000100 - start of ATAGS
// r15 -> should begin execution at 0x8000.
export nakedcc fn _start() -> unreachable {
    // to keep this in the first portion of the binary
    @setGlobalSection(_start, ".text.boot");

    // set up the stack and
    // enable vector operations
    asm volatile (
        \\ mov sp, #0x8000
        \\ mov r0, #0x00f00000
        \\ mcr p15, 0, r0, c1, c0, 2
        \\ isb
        \\ mov r0, #0x40000000
        \\ vmsr FPEXC, r0
    : : : "r0");

    // clear .bss
    @memset(&volatile __bss_start, 0, usize(&__bss_end) - usize(&__bss_start));

    kernel_main();
}

pub fn panic(message: []const u8) -> unreachable {
    uart_write(message);
    uart_write("\n!KERNEL PANIC!\n");
    while (true) {
        asm volatile ("wfe");
    }
}

fn mmio_write(reg: usize, data: u32) {
    @fence(AtomicOrder.SeqCst);
    *(&volatile u32)(reg) = data;
}

fn mmio_read(reg: usize) -> u32 {
    @fence(AtomicOrder.SeqCst);
    return *(&volatile usize)(reg);
}

// Loop count times in a way that the compiler won't optimize away.
fn delay(count: usize) {
    var i: usize = 0;
    while (i < count; i += 1) {
        asm volatile("mov r0, r0");
    }
}

// The GPIO registers base address.
const GPIO_BASE = 0x3F200000;

// The offsets for reach register.

// Controls actuation of pull up/down to ALL GPIO pins.
const GPPUD = (GPIO_BASE + 0x94);

// Controls actuation of pull up/down for specific GPIO pin.
const GPPUDCLK0 = (GPIO_BASE + 0x98);

// The base address for UART.
const UART0_BASE = 0x3F201000;

// The offsets for reach register for the UART.
const UART0_DR     = (UART0_BASE + 0x00);
const UART0_RSRECR = (UART0_BASE + 0x04);
const UART0_FR     = (UART0_BASE + 0x18);
const UART0_ILPR   = (UART0_BASE + 0x20);
const UART0_IBRD   = (UART0_BASE + 0x24);
const UART0_FBRD   = (UART0_BASE + 0x28);
const UART0_LCRH   = (UART0_BASE + 0x2C);
const UART0_CR     = (UART0_BASE + 0x30);
const UART0_IFLS   = (UART0_BASE + 0x34);
const UART0_IMSC   = (UART0_BASE + 0x38);
const UART0_RIS    = (UART0_BASE + 0x3C);
const UART0_MIS    = (UART0_BASE + 0x40);
const UART0_ICR    = (UART0_BASE + 0x44);
const UART0_DMACR  = (UART0_BASE + 0x48);
const UART0_ITCR   = (UART0_BASE + 0x80);
const UART0_ITIP   = (UART0_BASE + 0x84);
const UART0_ITOP   = (UART0_BASE + 0x88);
const UART0_TDR    = (UART0_BASE + 0x8C);

fn uart_init() {
    // Disable UART0.
    mmio_write(UART0_CR, 0x00000000);
    // Setup the GPIO pin 14 && 15.

    // Disable pull up/down for all GPIO pins & delay for 150 cycles.
    mmio_write(GPPUD, 0x00000000);
    delay(150);

    // Disable pull up/down for pin 14,15 & delay for 150 cycles.
    mmio_write(GPPUDCLK0, (1 << 14) | (1 << 15));
    delay(150);

    // Write 0 to GPPUDCLK0 to make it take effect.
    mmio_write(GPPUDCLK0, 0x00000000);

    // Clear pending interrupts.
    mmio_write(UART0_ICR, 0x7FF);

    // Set integer & fractional part of baud rate.
    // Divider = UART_CLOCK/(16 * Baud)
    // Fraction part register = (Fractional part * 64) + 0.5
    // UART_CLOCK = 3000000; Baud = 115200.

    // Divider = 3000000 / (16 * 115200) = 1.627 = ~1.
    // Fractional part register = (.627 * 64) + 0.5 = 40.6 = ~40.
    mmio_write(UART0_IBRD, 1);
    mmio_write(UART0_FBRD, 40);

    // Enable FIFO & 8 bit data transmissio (1 stop bit, no parity).
    mmio_write(UART0_LCRH, (1 << 4) | (1 << 5) | (1 << 6));

    // Mask all interrupts.
    mmio_write(UART0_IMSC, (1 << 1) | (1 << 4) | (1 << 5) | (1 << 6) |
                           (1 << 7) | (1 << 8) | (1 << 9) | (1 << 10));

    // Enable UART0, receive & transfer part of UART.
    mmio_write(UART0_CR, (1 << 0) | (1 << 8) | (1 << 9));
}

fn uart_putc(byte: u8) {
    // Wait for UART to become ready to transmit.
    while ( (mmio_read(UART0_FR) & (1 << 5)) != 0 ) { }
    mmio_write(UART0_DR, byte);
}

fn uart_getc() -> u8 {
    // Wait for UART to have recieved something.
    while ( (mmio_read(UART0_FR) & (1 << 4)) != 0 ) { }
    const c = @truncate(u8, mmio_read(UART0_DR));
    return if (c == '\r') '\n' else c;
}

fn uart_write(buffer: []const u8) {
    for (buffer) |c| uart_putc(c);
}

fn debugDumpMemory(address: usize, size: usize) {
    var i: usize = 0;
    while (i < size; i += 1) {
        const full_addr = address + i;

        if (i % 16 == 0) {
            log("\n0x{x8}  ", full_addr);
        } else if (i % 8 == 0) {
            log(" ");
        }

        log(" {x2}", *(&const u8)(full_addr));
    }
    log("\n");
}

// TODO use the std io formating code instead of duplicating
fn log(comptime format: []const u8, args: ...) {
    const State = enum {
        Start,
        OpenBrace,
        CloseBrace,
        Integer,
        IntegerWidth,
    };
    comptime var start_index: usize = 0;
    comptime var state = State.Start;
    comptime var next_arg: usize = 0;
    comptime var radix = 0;
    comptime var uppercase = false;
    comptime var width: usize = 0;
    comptime var width_start: usize = 0;
    inline for (format) |c, i| {
        switch (state) {
            State.Start => switch (c) {
                '{' => {
                    if (start_index < i) uart_write(format[start_index...i]);
                    state = State.OpenBrace;
                },
                '}' => {
                    if (start_index < i) uart_write(format[start_index...i]);
                    state = State.CloseBrace;
                },
                else => {},
            },
            State.OpenBrace => switch (c) {
                '{' => {
                    state = State.Start;
                    start_index = i;
                },
                '}' => {
                    logValue(args[next_arg]);
                    next_arg += 1;
                    state = State.Start;
                    start_index = i + 1;
                },
                'd' => {
                    radix = 10;
                    uppercase = false;
                    width = 0;
                    state = State.Integer;
                },
                'x' => {
                    radix = 16;
                    uppercase = false;
                    width = 0;
                    state = State.Integer;
                },
                'X' => {
                    radix = 16;
                    uppercase = true;
                    width = 0;
                    state = State.Integer;
                },
                else => @compileError("Unknown format character: " ++ c),
            },
            State.CloseBrace => switch (c) {
                '}' => {
                    state = State.Start;
                    start_index = i;
                },
                else => @compileError("Single '}' encountered in format string"),
            },
            State.Integer => switch (c) {
                '}' => {
                    logInt(args[next_arg], radix, uppercase, width);
                    next_arg += 1;
                    state = State.Start;
                    start_index = i + 1;
                },
                '0' ... '9' => {
                    width_start = i;
                    state = State.IntegerWidth;
                },
                else => @compileError("Unexpected character in format string: " ++ c),
            },
            State.IntegerWidth => switch (c) {
                '}' => {
                    width = comptime %%io.parseUnsigned(usize, format[width_start...i], 10);
                    logInt(args[next_arg], radix, uppercase, width);
                    next_arg += 1;
                    state = State.Start;
                    start_index = i + 1;
                },
                '0' ... '9' => {},
                else => @compileError("Expected '}' after 'x'/'X' in format string"),
            },
        }
    }
    comptime {
        if (args.len != next_arg) {
            @compileError("Unused arguments");
        }
        switch (state) {
            State.Start => {},
            else => @compileError("Incomplete format string: " ++ format),
        }
    }
    if (start_index < format.len) {
        uart_write(format[start_index...format.len]);
    }
}

fn logValue(value: var) {
    const T = @typeOf(value);
    if (@isInteger(T)) {
        return logInt(value, 10, false, 0);
    } else if (@canImplicitCast([]const u8, value)) {
        const casted_value = ([]const u8)(value);
        return uart_write(casted_value);
    } else if (T == void) {
        return uart_write("void");
    } else {
        @compileError("Unable to print type '" ++ @typeName(T) ++ "'");
    }
}

fn bigTimeExtraMemoryBarrier() {
    asm volatile (
        \\ mcr    p15, 0, ip, c7, c5, 0        @ invalidate I cache
        \\ mcr    p15, 0, ip, c7, c5, 6        @ invalidate BTB
        \\ dsb
        \\ isb
    );
}

fn logInt(value: var, base: u8, uppercase: bool, width: usize) {
    var buf: [65]u8 = undefined;
    const amt_printed = io.bufPrintInt(buf[0...], value, base, uppercase, width);
    uart_write(buf[0...amt_printed]);
}

fn kernel_main() -> unreachable {
    uart_init();
    log("ClashOS 0.0\n");

    while (true) {
        try(fb_init()) {
            break;
        } else {
            panic("Unable to initialize framebuffer");
        }
    }

    log("Screen size: {}x{}\n", fb_info.width, fb_info.height);

    fb_clear(&color_blue);

    while (true) {
        uart_putc(uart_getc());
    }
}

const color_blue = Color { .red = 0, .green = 0, .blue = 255 };

var fb_info: FbInfo = undefined;

const FbInfo = struct {
    // Stuff about the pixel frame buffer
    width: usize,
    height: usize,
    pitch: usize, //BCM2836 has this separate, so we use this instead of witdh
    ptr: &volatile u8,
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

error NonZeroFrameBufferResponse;
error NullFrameBufferPointer;

fn fb_init() -> %void {
    log("Initializing frame buffer...\n");

    // We need to put the frame buffer structure somewhere with the lower 4 bits zero.
    // 0x400000 is a convenient place not used by anything, and with sufficient alignment
    const fb = (&volatile Bcm2836FrameBuffer)(0x400000);

    const width = 640;
    const height = 480;

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

    // Tell the GPU the address of the structure
    mbox_write(ArmToVc(usize(fb)));

    // Wait for the GPU to respond, and get its response
    const response = mbox_read();
    if (response != 0) return error.NonZeroFrameBufferResponse;
    if (fb.pointer == 0) return error.NullFrameBufferPointer;

    fb_info.ptr = (&u8)(VcToArm(fb.pointer));
    fb_info.size = fb.size;
    fb_info.width = fb.width;
    fb_info.height = fb.height;
    fb_info.pitch = fb.pitch;
}

fn fb_clear(color: &const Color) {
    {var y: usize = 0; while (y < fb_info.height; y += 1) {
        {var x: usize = 0; while (x < fb_info.width; x += 1) {
            const offset = y * fb_info.pitch + x * 3;
            fb_info.ptr[offset] = color.red;
            fb_info.ptr[offset + 1] = color.green;
            fb_info.ptr[offset + 2] = color.blue;
        }}
    }}
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

fn mbox_write(v: u32) {
    // wait for space
    while (mmio_read(MAIL_STATUS) & MAIL_FULL != 0) {}
    // Write the value to the frame buffer channel
    mmio_write(MAIL_WRITE, MAIL_FB | (v & 0xFFFFFFF0));
}

fn mbox_read() -> u32 {
    while (true) {
        // wait for data
        while (mmio_read(MAIL_STATUS) & MAIL_EMPTY != 0) {}
        const result = mmio_read(MAIL_READ);

        // Loop until we received something from the
        // frame buffer channel
        if ((result & 0xf) == MAIL_FB)
            return result & 0xFFFFFFF0;
    }
}

fn ArmToVc(addr: usize) -> usize {
    // Some things (e.g: the GPU) expect bus addresses, not ARM physical
    // addresses
    addr + 0xC0000000
}

fn VcToArm(addr: usize) -> usize {
    // Go the other way to ArmToVc
    addr - 0xC0000000
}
