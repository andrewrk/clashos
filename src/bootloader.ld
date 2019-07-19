ENTRY(boot)

SECTIONS {
    kernel_main = 0x1000; /* Must match value from kernel linker script */

    . = 0x8800000; /* Must match debug.bootloader_address */

    .text : ALIGN(4K) {
        KEEP(*(.text.first))
        *(.text)
    }

    .rodata : ALIGN(4K) {
        *(.rodata)
    }

    .data : ALIGN(4K) {
        *(.data)
    }

    .bss : ALIGN(4K) {
        __bss_start = .;
        *(COMMON)
        *(.bss)
        __bss_end = .;
    }
}

