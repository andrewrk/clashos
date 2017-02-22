pub fn write(reg: usize, data: u32) {
    @fence(AtomicOrder.SeqCst);
    *(&volatile u32)(reg) = data;
}

pub fn read(reg: usize) -> u32 {
    @fence(AtomicOrder.SeqCst);
    return *(&volatile usize)(reg);
}

pub fn bigTimeExtraMemoryBarrier() {
    asm volatile (
        \\ mcr    p15, 0, ip, c7, c5, 0        @ invalidate I cache
        \\ mcr    p15, 0, ip, c7, c5, 6        @ invalidate BTB
        \\ dsb
        \\ isb
    );
}

