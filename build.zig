const std = @import("std");
const Builder = std.build.Builder;
const builtin = @import("builtin");

pub fn build(b: *Builder) !void {
    const mode = b.standardReleaseOptions();
    const want_gdb = b.option(bool, "gdb", "Build for using gdb with qemu") orelse false;

    const exec_name = if (want_gdb) "clashos-dbg" else "clashos";
    const exe = b.addStaticExecutable(exec_name, "src/main.zig");
    exe.setBuildMode(mode);
    exe.setTarget(builtin.Arch.aarch64v8, builtin.Os.freestanding, builtin.Environ.eabihf);
    const linker_script = if (want_gdb) "src/qemu-gdb.ld" else "src/linker.ld";
    exe.setLinkerScriptPath(linker_script);

    const run_objcopy = b.addCommand(null, b.env_map, [][]const u8{
        "objcopy", exe.getOutputPath(),
        "-O", "binary",
        "clashos.bin",
    });
    run_objcopy.step.dependOn(&exe.step);

    b.default_step.dependOn(&run_objcopy.step);

    const qemu = b.step("qemu", "Run the OS in qemu");
    var qemu_args = std.ArrayList([]const u8).init(b.allocator);
    try qemu_args.appendSlice([][]const u8{
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
    if (want_gdb) {
        try qemu_args.appendSlice([][]const u8{ "-S", "-s" });
    }
    const run_qemu = b.addCommand(null, b.env_map, qemu_args.toSliceConst());
    qemu.dependOn(&run_qemu.step);
    run_qemu.step.dependOn(&exe.step);
}
