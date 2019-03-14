const std = @import("std");
const Builder = std.build.Builder;
const builtin = @import("builtin");

pub fn build(b: *Builder) !void {
    const mode = b.standardReleaseOptions();
    const want_gdb = b.option(bool, "gdb", "Build for using gdb with qemu") orelse false;
    const want_pty = b.option(bool, "pty", "Create a separate TTY path") orelse false;

    const arch = builtin.Arch{ .aarch64 = builtin.Arch.Arm64.v8 };
    const environ = builtin.Abi.eabihf;

    // First we build just the bootloader executable, and then we build the actual kernel
    // which uses @embedFile on the bootloader.
    const bootloader = b.addExecutable("bootloader", "src/bootloader.zig");
    bootloader.setLinkerScriptPath("src/bootloader.ld");
    bootloader.setBuildMode(builtin.Mode.ReleaseSmall);
    bootloader.setTarget(arch, builtin.Os.freestanding, environ);
    bootloader.strip = true;
    bootloader.setOutputDir("zig-cache");

    const exec_name = if (want_gdb) "clashos-dbg" else "clashos";
    const exe = b.addExecutable(exec_name, "src/main.zig");
    exe.setOutputDir("zig-cache");
    exe.setBuildMode(mode);
    exe.setTarget(arch, builtin.Os.freestanding, environ);
    const linker_script = if (want_gdb) "src/qemu-gdb.ld" else "src/linker.ld";
    exe.setLinkerScriptPath(linker_script);
    exe.addBuildOption([]const u8, "bootloader_exe_path", b.fmt("\"{}\"", bootloader.getOutputPath()));
    exe.step.dependOn(&bootloader.step);

    const run_objcopy = b.addSystemCommand([][]const u8{
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
        if (want_pty) "pty" else "stdio",
    });
    if (want_gdb) {
        try qemu_args.appendSlice([][]const u8{ "-S", "-s" });
    }
    const run_qemu = b.addSystemCommand(qemu_args.toSliceConst());
    qemu.dependOn(&run_qemu.step);
    run_qemu.step.dependOn(&exe.step);

    const send_image_tool = b.addExecutable("send_image", "tools/send_image.zig");

    const run_send_image_tool = send_image_tool.run();
    if (b.option([]const u8, "tty", "Specify the TTY to send images to")) |tty_path| {
        run_send_image_tool.addArg(tty_path);
    }

    const upload = b.step("upload", "Send a new kernel image to a running instance. (See -Dtty option)");
    upload.dependOn(&run_objcopy.step);
    upload.dependOn(&run_send_image_tool.step);
}
