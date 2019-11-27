const std = @import("std");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.direct_allocator);
    defer arena.deinit();

    const allocator = &arena.allocator;
    const args = try std.process.argsAlloc(allocator);
    if (args.len != 2) {
        std.debug.panic("expected 2 args, found {} args", .{args.len});
    }
    const file_path = args[1];
    const new_image_data = try std.io.readFileAlloc(allocator, "clashos.bin");
    const tty_fd = try std.fs.File.openWrite(file_path);
    const out = &tty_fd.outStream().stream;

    try out.write(&[_]u8{ 6, 6, 6 });

    // sleep some time to allow the RPI to send logging data...
    std.time.sleep(50 * std.time.millisecond);

    try out.writeIntLittle(u32, @intCast(u32, new_image_data.len));
    std.time.sleep(50 * std.time.millisecond);

    try out.write(new_image_data);
}
