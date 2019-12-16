const builtin = @import("builtin");
const std = @import("std");
const build_options = @import("build_options");
const assert = std.debug.assert;
const serial = @import("serial.zig");

extern var __debug_info_start: u8;
extern var __debug_info_end: u8;
extern var __debug_abbrev_start: u8;
extern var __debug_abbrev_end: u8;
extern var __debug_str_start: u8;
extern var __debug_str_end: u8;
extern var __debug_line_start: u8;
extern var __debug_line_end: u8;
extern var __debug_ranges_start: u8;
extern var __debug_ranges_end: u8;

const source_files = [_][]const u8{
    "src/main.zig",
    "src/bootloader.zig",
    "src/debug.zig",
    "src/serial.zig",
    "src/time.zig",
    "src/mmio.zig",
    "src/exceptions.zig",
    "src/video_core_metrics.zig",
    "src/video_core_properties.zig",
    "src/video_core_frame_buffer.zig",
    "src/video_core_mailboxes.zig",
    "src/slice_iterator.zig",
};

var already_panicking: bool = false;

pub fn panic(stack_trace: ?*builtin.StackTrace, comptime fmt: []const u8, args: var) noreturn {
    @setCold(true);
    if (already_panicking) {
        serial.log("panicked during kernel panic!!\n", .{});
        wfeHang();
    }
    already_panicking = true;

    serial.log("panic: " ++ fmt ++ "\n", args);

    const first_trace_addr = @returnAddress();
    if (build_options.want_stack_traces) {
        if (stack_trace) |t| {
            dumpStackTrace(t);
        }
        dumpCurrentStackTrace(first_trace_addr);
    } else {
        serial.log("Stack trace:\n", .{});
        var it = std.debug.StackIterator{ .first_addr = null, .fp = @frameAddress() };
        while (it.next()) |return_address| {
            if (return_address == 0) break;

            serial.log("  0x{x}\n", .{return_address - 4});
        }
        serial.log("The stack trace can be decoded using `addr2line -e zig-cache/clashos <address>`\n\n", .{});
        serial.log("To get stack traces during runtime, enable them using `zig build -Dstacktraces`\n", .{});
    }
    wfeHang();
}

pub fn wfeHang() noreturn {
    while (true) {
        asm volatile ("wfe");
    }
}

fn dwarfSectionFromSymbolAbs(start: *u8, end: *u8) std.debug.DwarfInfo.Section {
    return std.debug.DwarfInfo.Section{
        .offset = 0,
        .size = @ptrToInt(end) - @ptrToInt(start),
    };
}

fn dwarfSectionFromSymbol(start: *u8, end: *u8) std.debug.DwarfInfo.Section {
    return std.debug.DwarfInfo.Section{
        .offset = @ptrToInt(start),
        .size = @ptrToInt(end) - @ptrToInt(start),
    };
}

fn getSelfDebugInfo() !*std.debug.DwarfInfo {
    const S = struct {
        var have_self_debug_info = false;
        var self_debug_info: std.debug.DwarfInfo = undefined;

        var in_stream_state = std.io.InStream(anyerror){ .readFn = readFn };
        var in_stream_pos: u64 = 0;
        const in_stream = &in_stream_state;

        fn readFn(self: *std.io.InStream(anyerror), buffer: []u8) anyerror!usize {
            const ptr = @intToPtr([*]const u8, in_stream_pos);
            @memcpy(buffer.ptr, ptr, buffer.len);
            in_stream_pos += buffer.len;
            return buffer.len;
        }

        const SeekableStream = std.io.SeekableStream(anyerror, anyerror);
        var seekable_stream_state = SeekableStream{
            .seekToFn = seekToFn,
            .seekByFn = seekByFn,

            .getPosFn = getPosFn,
            .getEndPosFn = getEndPosFn,
        };
        const seekable_stream = &seekable_stream_state;

        fn seekToFn(self: *SeekableStream, pos: u64) anyerror!void {
            in_stream_pos = pos;
        }
        fn seekByFn(self: *SeekableStream, pos: i64) anyerror!void {
            in_stream_pos = @bitCast(usize, @bitCast(isize, in_stream_pos) +% pos);
        }
        fn getPosFn(self: *SeekableStream) anyerror!u64 {
            return in_stream_pos;
        }
        fn getEndPosFn(self: *SeekableStream) anyerror!u64 {
            return @as(u64, @ptrToInt(&__debug_ranges_end));
        }
    };
    if (S.have_self_debug_info) return &S.self_debug_info;

    S.self_debug_info = std.debug.DwarfInfo{
        .dwarf_seekable_stream = S.seekable_stream,
        .dwarf_in_stream = S.in_stream,
        .endian = builtin.Endian.Little,
        .debug_info = dwarfSectionFromSymbol(&__debug_info_start, &__debug_info_end),
        .debug_abbrev = dwarfSectionFromSymbolAbs(&__debug_abbrev_start, &__debug_abbrev_end),
        .debug_str = dwarfSectionFromSymbolAbs(&__debug_str_start, &__debug_str_end),
        .debug_line = dwarfSectionFromSymbolAbs(&__debug_line_start, &__debug_line_end),
        .debug_ranges = dwarfSectionFromSymbolAbs(&__debug_ranges_start, &__debug_ranges_end),
        .abbrev_table_list = undefined,
        .compile_unit_list = undefined,
        .func_list = undefined,
    };
    try std.debug.openDwarfDebugInfo(&S.self_debug_info, kernel_panic_allocator);
    return &S.self_debug_info;
}

var serial_out_stream_state = std.io.OutStream(anyerror){
    .writeFn = struct {
        fn logWithSerial(self: *std.io.OutStream(anyerror), bytes: []const u8) anyerror!void {
            serial.writeText(bytes);
        }
    }.logWithSerial,
};
const serial_out_stream = &serial_out_stream_state;
var kernel_panic_allocator_bytes: [5 * 1024 * 1024]u8 = undefined;
var kernel_panic_allocator_state = std.heap.FixedBufferAllocator.init(kernel_panic_allocator_bytes[0..]);
const kernel_panic_allocator = &kernel_panic_allocator_state.allocator;

pub fn dumpStackTrace(stack_trace: *const builtin.StackTrace) void {
    const dwarf_info = getSelfDebugInfo() catch |err| {
        serial.log("Unable to dump stack trace: Unable to open debug info: {}", .{@errorName(err)});
        return;
    };
    writeStackTrace(stack_trace, dwarf_info) catch |err| {
        serial.log("Unable to dump stack trace: {}", .{@errorName(err)});
        return;
    };
}

pub fn dumpCurrentStackTrace(start_addr: ?usize) void {
    const dwarf_info = getSelfDebugInfo() catch |err| {
        serial.log("Unable to dump stack trace: Unable to open debug info: {}", .{@errorName(err)});
        return;
    };
    writeCurrentStackTrace(dwarf_info, start_addr) catch |err| {
        serial.log("Unable to dump stack trace: {}", .{@errorName(err)});
        return;
    };
}

fn printLineFromBuffer(out_stream: var, contents: []const u8, line_info: std.debug.LineInfo) anyerror!void {
    var line: usize = 1;
    var column: usize = 1;
    var abs_index: usize = 0;
    for (contents) |byte| {
        if (line == line_info.line) {
            try out_stream.writeByte(byte);
            if (byte == '\n') {
                return;
            }
        }
        if (byte == '\n') {
            line += 1;
            column = 1;
        } else {
            column += 1;
        }
    }
    return error.EndOfFile;
}

fn printLineFromFile(out_stream: var, line_info: std.debug.LineInfo) anyerror!void {
    inline for (source_files) |src_path| {
        if (std.mem.endsWith(u8, line_info.file_name, src_path)) {
            const contents = @embedFile("../" ++ src_path);
            try printLineFromBuffer(out_stream, contents[0..], line_info);
            return;
        }
    }
    try out_stream.print("(source file {} not added in std.debug.zig)\n", .{line_info.file_name});
}

fn writeCurrentStackTrace(dwarf_info: *std.debug.DwarfInfo, start_addr: ?usize) !void {
    var it = std.debug.StackIterator.init(start_addr);
    while (it.next()) |return_address| {
        if (return_address == 0) break;

        try dwarf_info.printSourceAtAddress(
            serial_out_stream,
            return_address - 4,
            true,
            printLineFromFile,
        );
    }
}

fn writeStackTrace(stack_trace: *const builtin.StackTrace, dwarf_info: *std.debug.DwarfInfo) !void {
    var frame_index: usize = undefined;
    var frames_left: usize = undefined;
    if (stack_trace.index < stack_trace.instruction_addresses.len) {
        frame_index = 0;
        frames_left = stack_trace.index;
    } else {
        frame_index = (stack_trace.index + 1) % stack_trace.instruction_addresses.len;
        frames_left = stack_trace.instruction_addresses.len;
    }

    while (frames_left != 0) : ({
        frames_left -= 1;
        frame_index = (frame_index + 1) % stack_trace.instruction_addresses.len;
    }) {
        const return_address = stack_trace.instruction_addresses[frame_index];
        try dwarf_info.printSourceAtAddress(
            serial_out_stream,
            return_address,
            true,
            printLineFromFile,
        );
    }
}
