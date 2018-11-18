# ClashOS

A work-in-progress 4-player arcade game that runs directly on the
Raspberry Pi 3 B+ hardware, written entirely in [Zig](https://ziglang.org/).

## Current Status

"Hello World" OS using UART2.

## Building

```
zig build
```

## Testing

```
zig build qemu
```

## Roadmap

 * Disable unused CPU cores to save power
 * Test it on actual hardware
 * Interface with the video driver
 * USB driver support for xbox360 controllers for testing the game

