pub fn of(comptime T: type) type {
    var Iterator = struct {
        const Self = @This();
        data: []T,
        index: u32,

        pub fn init(data: []T) Self {
            var self: Self = undefined;
            self.data = data;
            self.index = 0;
            return self;
        }

        fn reset(self: *Self) void {
            self.index = 0;
        }

        fn add(self: *Self, item: T) !void {
            try self.advance();
            self.data[self.index - 1] = item;
        }

        fn next(self: *Self) !u32 {
            try self.advance();
            return self.data[self.index - 1];
        }

        fn advance(self: *Self) !void {
            if (self.index < self.data.len) {
                self.index += 1;
            } else {
                return error.BufferExhausted;
            }
        }
    };

    return Iterator;
}
