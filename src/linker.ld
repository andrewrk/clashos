ENTRY(_start)

SECTIONS {
    . = 0x0000;

    .text : ALIGN(4K) {
        KEEP(*(.text.boot))
        *(.text)
    }

    .rodata : ALIGN(4K) {
        *(.rodata)
    }

    .data : ALIGN(4K) {
        *(.data)
    }

    __bss_start = .;
    .bss : ALIGN(4K) {
        *(COMMON)
        *(.bss)
    }
    __bss_end = .;
}
