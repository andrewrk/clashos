const serial = @import("serial.zig");
const debug = @import("debug.zig");

comptime {
    asm (
        \\.section .text
        \\.balign 0x800
        \\exception_vector_table:
        \\.balign 0x80
        \\ bl exceptionHandler
        \\.balign 0x80
        \\ bl exceptionHandler
        \\.balign 0x80
        \\ bl exceptionHandler
        \\.balign 0x80
        \\ bl exceptionHandler
        \\.balign 0x80
        \\ bl exceptionHandler
        \\.balign 0x80
        \\ bl exceptionHandler
        \\.balign 0x80
        \\ bl exceptionHandler
        \\.balign 0x80
        \\ bl exceptionHandler
    );
}

pub fn init() void {
    asm volatile (
        \\ adr x0, exception_vector_table
        \\ msr vbar_el2,x0
    );
}

export fn exceptionHandler() void {
    serial.log("arm exception taken\n", .{});
    var current_el = asm ("mrs %[current_el], CurrentEL\n"
        : [current_el] "=r" (-> usize)
    );
    serial.log("CurrentEL {x} exception level {}\n", .{ current_el, current_el >> 2 & 0x3 });
    var esr_el2 = asm ("mrs %[esr_el2], esr_el2"
        : [esr_el2] "=r" (-> usize)
    );
    serial.log("esr_el2 {x} code 0x{x}\n", .{ esr_el2, esr_el2 >> 26 & 0x3f });
    var elr_el2 = asm ("mrs %[elr_el2], elr_el2"
        : [elr_el2] "=r" (-> usize)
    );
    serial.log("elr_el2 {x}\n", .{elr_el2});
    var spsr_el2 = asm ("mrs %[spsr_el2], spsr_el2"
        : [spsr_el2] "=r" (-> usize)
    );
    serial.log("spsr_el2 {x}\n", .{spsr_el2});
    var far_el2 = asm ("mrs %[far_el2], far_el2"
        : [far_el2] "=r" (-> usize)
    );
    serial.log("far_el2 {x}\n", .{far_el2});
    serial.log("execution is now stopped in arm exception handler\n", .{});

    debug.panic(null, "exception!!!", .{});
}
