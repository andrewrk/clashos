# ClashOS

A work-in-progress 4-player arcade game that runs directly on the
Raspberry Pi 3 hardware, written entirely in [Zig](http://ziglang.org/).

## Testing

```
qemu-system-arm -kernel clashos -m 256 -M raspi2 -serial stdio
```
