const Builder = @import("std").build.Builder;
const builtin = @import("builtin");

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();

    const exe = b.addStaticExecutable("clashos", "src/main.zig");
    exe.setBuildMode(mode);
    exe.setTarget(builtin.Arch.aarch64v8, builtin.Os.freestanding, builtin.Environ.eabihf);
    exe.setLinkerScriptPath("src/linker.ld");

    const run_objcopy = b.addCommand(null, b.env_map, [][]const u8{
        "objcopy", exe.getOutputPath(),
        "-O", "binary",
        "clashos.bin",
    });
    run_objcopy.step.dependOn(&exe.step);

    b.default_step.dependOn(&run_objcopy.step);

    const qemu = b.step("qemu", "Run the OS in qemu");
    const run_qemu = b.addCommand(null, b.env_map, [][]const u8{
        "qemu-system-aarch64",
        "-kernel",
        exe.getOutputPath(),
        "-m",
        "256",
        "-M",
        "raspi3",
        "-serial",
        "null",
        "-serial",
        "stdio",
    });
    qemu.dependOn(&run_qemu.step);
    run_qemu.step.dependOn(&exe.step);
}
