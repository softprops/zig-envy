# envy

deserialize environment variables into typesafe structs

```zig
const std = @import("std");
const envy = @import("envy");

const Config = struct {
    foo: u16,
    bar: bool,
    baz: []const u8,
    boom: ?u46
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const config = envy.parse(Config, allocator, .{}) catch |err| {
        std.debug.print("error parsing config from env: {any}", err);
        return;
    };
    std.debug.println("config {any}", .{ config });
}
```
