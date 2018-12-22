const std = @import("std");

pub fn main() !void {
    var direct_allocator = std.heap.DirectAllocator.init();
    defer direct_allocator.deinit();

    var arena = std.heap.ArenaAllocator.init(&direct_allocator.allocator);
    defer arena.deinit();

    const allocator = &arena.allocator;
    const args = try std.os.argsAlloc(allocator);
    if (args.len != 2) {
        std.debug.panic("expected 2 args, found {} args", args.len);
    }
    const file_path = args[1];
    const new_image_data = try std.io.readFileAlloc(allocator, "clashos.bin");
    const tty_fd = try std.os.posixOpen(file_path, std.os.posix.O_WRONLY, 0);
    const tty_file = std.os.File.openHandle(tty_fd);
    const out = &tty_file.outStream().stream;
    try out.write([]u8{ 6, 6, 6 });
    try out.writeIntLittle(u32, @intCast(u32, new_image_data.len));
    try out.write(new_image_data);
}
