<h1 align="center">
    envy
</h1>

<div align="center>
    deserialize environment variables into typesafe structs
</div>

![Zig Support](https://img.shields.io/badge/zig-0.11.0-yellow?logo=zig&color=black)
 [![Main](https://github.com/softprops/zig-envy/actions/workflows/main.yml/badge.svg)](https://github.com/softprops/zig-envy/actions/workflows/main.yml) ![License Info](https://img.shields.io/github/license/softprops/zig-envy) ![Release](https://img.shields.io/github/v/release/softprops/zig-envy)

## 🍬 features

- fail fast on faulty application configuration
- supports parsable std lib types out of the box
- fail at compile time for unsupported field types

## examples

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
