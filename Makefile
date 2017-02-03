ZIG=/home/andy/dev/zig/build/zig
LD=/home/andy/local/i386/bin/i686-elf-ld
AR=/home/andy/local/i386/bin/i686-elf-ar


all:
	$(ZIG) build kernel.zig --export exe --name clashos --target-os freestanding --target-arch i386 --linker-script linker.ld --ld-path $(LD) --ar-path $(AR) --static --release
	grub-file --is-x86-multiboot clashos
	mkdir -p out/iso/boot/grub
	cp grub.cfg out/iso/boot/grub/grub.cfg
	cp clashos out/iso/boot/clashos.bin
	grub-mkrescue -o clashos.iso out/iso/
