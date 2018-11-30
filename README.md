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

 * Test it on actual hardware
 * Interface with the file system
 * Ability to send a new kernel image via UART
 * Interface with the video driver
 * Get a simple joystick and button and use GPIO
 * Sound (should it be the analog or over HDMI)?
 * Make the game
 * Build arcade cabinets
