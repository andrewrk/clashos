const Builder = @import("std").build.Builder;
const builtin = @import("builtin");

pub fn build(b: &Builder) -> %void {
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("clashos", "src/main.zig");
    exe.setBuildMode(mode);
    exe.setOutputPath("clashos");
    exe.setTarget(builtin.Arch.armv7, builtin.Os.freestanding, builtin.Environ.gnueabihf);
    exe.setLinkerScriptPath("src/linker.ld");

    b.default_step.dependOn(&exe.step);

    const qemu = b.step("qemu", "Run the OS in qemu");
    const run_qemu = b.addCommand(".", b.env_map, [][]const u8 {
        "qemu-system-arm", 
        "-kernel", "clashos",
        "-m", "256",
        "-M", "raspi2",
        "-serial", "stdio",
    });
    qemu.dependOn(&run_qemu.step);
    run_qemu.step.dependOn(&exe.step);
}
