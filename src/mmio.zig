const AtomicOrder = @import("builtin").AtomicOrder;

pub fn write(reg: usize, data: u32) void {
    @fence(AtomicOrder.SeqCst);
    @intToPtr(*volatile u32, reg).* = data;
}

pub fn read(reg: usize) u32 {
    @fence(AtomicOrder.SeqCst);
    return @intToPtr(*volatile usize, reg).*;
}

pub fn bigTimeExtraMemoryBarrier() void {
    asm volatile (
        \\ mcr    p15, 0, ip, c7, c5, 0        @ invalidate I cache
        \\ mcr    p15, 0, ip, c7, c5, 6        @ invalidate BTB
        \\ dsb
        \\ isb
    );
}

