# ClashOS

A work-in-progress multiplayer arcade game that runs directly on the
Raspberry Pi 3 B+ hardware, written entirely in [Zig](https://ziglang.org/).

## Current Status

"Hello World" OS using the MiniUART. Tested and working on real hardware.

## Building

```
zig build
```

## Testing

### QEMU

```
zig build qemu
```

#### Debugging with GDB

```
zig build qemu -Dgdb
```

In another terminal:

```
gdb zig-cache/clashos-dbg -ex 'run target remote localhost:1234'
```

Note: this crashes GDB for me, but it works if I remove the `-ex`
parameter and execute the command at the prompt.

### Actual Hardware

1. Mount an sdcard with a single FAT32 partition.
2. Copy `boot/*` to `/path/to/sdcard/*`.
3. `zig build`
4. Copy `clashos.bin` to `/path/to/sdcard/kernel7.img`.

For further changes repeat steps 3 and 4.

## Roadmap

 * Ability to send a new kernel image via UART
 * Interface with the file system
 * Get rid of dependency on binutils objcopy
 * Interface with the video driver
 * Get a simple joystick and button and use GPIO
 * Sound (should it be the analog or over HDMI)?
 * Make the game
 * Build arcade cabinets

## Documentation

### EZSync 012 USB Cable

 * Black: Pin 6, Ground
 * Yellow: Pin 8, BCM 14, TXD / Transmit
 * Orange: Pin 10, BCM 15, RXD / Receive

### How to view the serial data

Where `/dev/ttyUSB0` is the device that represents the serial-to-USB cable:

```
sudo screen /dev/ttyUSB0 115200 cs8
```
