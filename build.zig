const Builder = @import("std").build.Builder;
const builtin = @import("builtin");

pub fn build(b: &Builder) {
    const release = b.option(bool, "release", "optimizations on and safety off") ?? false;

    const exe = b.addExecutable("clashos", "src/main.zig");
    exe.setRelease(release);
    exe.setOutputPath("clashos");
    exe.setTarget(builtin.Arch.armv7, builtin.Os.freestanding, builtin.Environ.gnueabihf);
    exe.setLinkerScriptPath("src/linker.ld");

    b.default_step.dependOn(&exe.step);
}
