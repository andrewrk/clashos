const Builder = @import("std").build.Builder;

pub fn build(b: &Builder) {
    const release = b.option(bool, "release", "optimizations on and safety off") ?? false;

    var exe = b.addExe("src/main.zig", "clashos");
    exe.setRelease(release);

    exe.setTarget(Arch.armv7, Os.freestanding, Environ.gnueabihf);
    exe.setLinkerScriptContents(
        \\ENTRY(_start)
        \\
        \\SECTIONS {
        \\    . = 0x8000;
        \\
        \\    .text : ALIGN(4K) {
        \\        KEEP(*(.text.boot))
        \\        *(.text)
        \\    }
        \\
        \\    .rodata : ALIGN(4K) {
        \\        *(.rodata)
        \\    }
        \\
        \\    .data : ALIGN(4K) {
        \\        *(.data)
        \\    }
        \\
        \\    __bss_start = .;
        \\    .bss : ALIGN(4K) {
        \\        *(COMMON)
        \\        *(.bss)
        \\    }
        \\    __bss_end = .;
        \\}
    );
}
