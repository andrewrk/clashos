const Builder = @import("std").build.Builder;

pub fn build(b: &Builder) {
    const release = b.option(bool, "release", "optimizations on and safety off") ?? false;

    const exe = b.addExecutable("clashos", "src/main.zig");
    exe.setRelease(release);

    exe.setTarget(Arch.armv7, Os.freestanding, Environ.gnueabihf);
    exe.setLinkerScriptPath("src/linker.ld");

    b.default_step.dependOn(&exe.step);
}
