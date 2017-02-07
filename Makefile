ZIG=/home/andy/dev/zig/build/zig
LD=/home/andy/local/arm-gnueabihf/bin/arm-linux-gnueabihf-ld
AR=/home/andy/local/arm-gnueabihf/bin/arm-linux-gnueabihf-ar

all:
	$(ZIG) build kernel.zig --export exe --name clashos --target-os freestanding --target-arch armv7 --target-environ gnueabihf --linker-script linker.ld --ld-path $(LD) --ar-path $(AR) --static

test: all
	qemu-system-arm -kernel clashos -m 256 -M raspi2 -serial stdio

clean:
	rm -f *.o clashos
