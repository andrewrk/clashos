const fmt = @import("std").fmt;
const mmio = @import("mmio.zig");

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
const UART0_DR = (UART0_BASE + 0x00);
const UART0_RSRECR = (UART0_BASE + 0x04);
const UART0_FR = (UART0_BASE + 0x18);
const UART0_ILPR = (UART0_BASE + 0x20);
const UART0_IBRD = (UART0_BASE + 0x24);
const UART0_FBRD = (UART0_BASE + 0x28);
const UART0_LCRH = (UART0_BASE + 0x2C);
const UART0_CR = (UART0_BASE + 0x30);
const UART0_IFLS = (UART0_BASE + 0x34);
const UART0_IMSC = (UART0_BASE + 0x38);
const UART0_RIS = (UART0_BASE + 0x3C);
const UART0_MIS = (UART0_BASE + 0x40);
const UART0_ICR = (UART0_BASE + 0x44);
const UART0_DMACR = (UART0_BASE + 0x48);
const UART0_ITCR = (UART0_BASE + 0x80);
const UART0_ITIP = (UART0_BASE + 0x84);
const UART0_ITOP = (UART0_BASE + 0x88);
const UART0_TDR = (UART0_BASE + 0x8C);

pub fn putc(byte: u8) void {
    // Wait for UART to become ready to transmit.
    while ((mmio.read(UART0_FR) & (1 << 5)) != 0) {}
    mmio.write(UART0_DR, byte);
}

pub fn getc() u8 {
    // Wait for UART to have recieved something.
    while ((mmio.read(UART0_FR) & (1 << 4)) != 0) {}
    const c = @truncate(u8, mmio.read(UART0_DR));
    return if (c == '\r') '\n' else c;
}

pub fn write(buffer: []const u8) void {
    for (buffer) |c|
        putc(c);
}

pub fn init() void {
    // Disable UART0.
    mmio.write(UART0_CR, 0x00000000);
    // Setup the GPIO pin 14 && 15.

    // Disable pull up/down for all GPIO pins & delay for 150 cycles.
    mmio.write(GPPUD, 0x00000000);
    delay(150);

    // Disable pull up/down for pin 14,15 & delay for 150 cycles.
    mmio.write(GPPUDCLK0, (1 << 14) | (1 << 15));
    delay(150);

    // Write 0 to GPPUDCLK0 to make it take effect.
    mmio.write(GPPUDCLK0, 0x00000000);

    // Clear pending interrupts.
    mmio.write(UART0_ICR, 0x7FF);

    // Set integer & fractional part of baud rate.
    // Divider = UART_CLOCK/(16 * Baud)
    // Fraction part register = (Fractional part * 64) + 0.5
    // UART_CLOCK = 3000000; Baud = 115200.

    // Divider = 3000000 / (16 * 115200) = 1.627 = ~1.
    // Fractional part register = (.627 * 64) + 0.5 = 40.6 = ~40.
    mmio.write(UART0_IBRD, 1);
    mmio.write(UART0_FBRD, 40);

    // Enable FIFO & 8 bit data transmissio (1 stop bit, no parity).
    mmio.write(UART0_LCRH, (1 << 4) | (1 << 5) | (1 << 6));

    // Mask all interrupts.
    mmio.write(UART0_IMSC, (1 << 1) | (1 << 4) | (1 << 5) | (1 << 6) |
        (1 << 7) | (1 << 8) | (1 << 9) | (1 << 10));

    // Enable UART0, receive & transfer part of UART.
    mmio.write(UART0_CR, (1 << 0) | (1 << 8) | (1 << 9));
}

const NoError = error{};

pub fn log(comptime format: []const u8, args: ...) void {
    fmt.format({}, NoError, logBytes, format, args) catch |e| switch (e) {};
}
fn logBytes(context: void, bytes: []const u8) NoError!void {
    write(bytes);
}

pub fn dumpMemory(address: usize, size: usize) void {
    var i: usize = 0;
    while (i < size) : (i += 1) {
        const full_addr = address + i;

        if (i % 16 == 0) {
            log("\n0x{x8}  ", full_addr);
        } else if (i % 8 == 0) {
            log(" ");
        }

        log(" {x2}", ((*const u8)(full_addr)).*);
    }
    log("\n");
}

// Loop count times in a way that the compiler won't optimize away.
fn delay(count: usize) void {
    var i: usize = 0;
    while (i < count) : (i += 1) {
        asm volatile ("mov r0, r0");
    }
}
