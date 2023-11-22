const std = @import("std");
const envy = @import("envy");

const Config = struct {
    foo: u16,
    bar: bool,
    baz: []const u8,
    boom: ?u64,
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const config = envy.parse(Config, allocator, .{}) catch |err| {
        std.debug.print("error parsing config from env: {any}", .{err});
        return;
    };
    std.debug.print("config {any}", .{config});
}
