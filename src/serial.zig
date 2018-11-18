const fmt = @import("std").fmt;
const mmio = @import("mmio.zig");

pub const GPFSEL1 = 0x3F200004;
pub const GPSET0 = 0x3F20001C;
pub const GPCLR0 = 0x3F200028;
pub const GPPUD = 0x3F200094;
pub const GPPUDCLK0 = 0x3F200098;

pub const AUX_ENABLES = 0x3F215004;
pub const AUX_MU_IO_REG = 0x3F215040;
pub const AUX_MU_IER_REG = 0x3F215044;
pub const AUX_MU_IIR_REG = 0x3F215048;
pub const AUX_MU_LCR_REG = 0x3F21504C;
pub const AUX_MU_MCR_REG = 0x3F215050;
pub const AUX_MU_LSR_REG = 0x3F215054;
pub const AUX_MU_MSR_REG = 0x3F215058;
pub const AUX_MU_SCRATCH = 0x3F21505C;
pub const AUX_MU_CNTL_REG = 0x3F215060;
pub const AUX_MU_STAT_REG = 0x3F215064;
pub const AUX_MU_BAUD_REG = 0x3F215068;

pub fn putc(byte: u8) void {
    // Wait for UART to become ready to transmit.
    while ((mmio.read(AUX_MU_LSR_REG) & 0x20) == 0) {}
    mmio.write(AUX_MU_IO_REG, byte);
}

pub fn getc() u8 {
    // Wait for UART to have recieved something.
    while ((mmio.read(AUX_MU_LSR_REG) & 0x01) == 0) {}
    return @truncate(u8, mmio.read(AUX_MU_IO_REG));
}

pub fn write(buffer: []const u8) void {
    for (buffer) |c|
        putc(c);
}

pub fn init() void {
    mmio.write(AUX_ENABLES, 1);
    mmio.write(AUX_MU_IER_REG, 0);

    mmio.write(AUX_MU_CNTL_REG, 0);
    mmio.write(AUX_MU_LCR_REG, 3);
    mmio.write(AUX_MU_MCR_REG, 0);
    mmio.write(AUX_MU_IER_REG, 0);
    mmio.write(AUX_MU_IIR_REG, 0xC6);
    mmio.write(AUX_MU_BAUD_REG, 270);
    var ra = mmio.read(GPFSEL1);
    ra &= ~u32(7 << 12); //gpio14
    ra |= 2 << 12; //alt5
    ra &= ~u32(7 << 15); //gpio15
    ra |= 2 << 15; //alt5
    mmio.write(GPFSEL1, ra);
    mmio.write(GPPUD, 0);
    delay(150);
    mmio.write(GPPUDCLK0, (1 << 14) | (1 << 15));
    delay(150);
    mmio.write(GPPUDCLK0, 0);
    mmio.write(AUX_MU_CNTL_REG, 3);
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
        asm volatile ("mov w0, w0");
    }
}
