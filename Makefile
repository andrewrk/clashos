ZIG=/home/andy/dev/zig/build/zig

all:
	$(ZIG) build src/main.zig --export exe --name clashos --target-os freestanding --target-arch armv7 --target-environ gnueabihf --linker-script linker.ld --static

test: all
	qemu-system-arm -kernel clashos -m 256 -M raspi2 -serial stdio

clean:
	rm -f *.o clashos
