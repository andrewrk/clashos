ENTRY(_start)

SECTIONS {
    . = 0x8000;

    .text BLOCK(4K) : ALIGN(4K) {
        KEEP(*(.text.boot))
        *(.text)
    }

    .rodata BLOCK(4K) : ALIGN(4K) {
        *(.rodata)
    }

    .data BLOCK(4K) : ALIGN(4K) {
        *(.data)
    }

    __bss_start = .;
    .bss BLOCK(4K) : ALIGN(4K) {
        *(COMMON)
        *(.bss)
    }
    __bss_end = .;
}
