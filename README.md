<h1 align="center">
    envy
</h1>

<div align="center>
    deserialize environment variables into typesafe structs
</div>

[![Main](https://github.com/softprops/zig-envy/actions/workflows/main.yml/badge.svg)](https://github.com/softprops/zig-envy/actions/workflows/main.yml) ![License Info](https://img.shields.io/github/license/softprops/zig-envy) ![Release](https://img.shields.io/github/v/release/softprops/zig-envy) ![Zig Support](https://img.shields.io/badge/zig-0.11.0-black?logo=zig)

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

## 📼 installing

Create a new exec project with `zig init-exe`. Copy the echo handler example above into `src/main.zig`

Create a `build.zig.zon` file to declare a dependency

> .zon short for "zig object notation" files are essential zig structs. `build.zig.zon` is zigs native package manager convention for where to declare dependencies

```zig
.{
    .name = "my-app",
    .version = "0.1.0",
    .dependencies = .{
        // 👇 declare dep properties
        .envy = .{
            // 👇 uri to download
            .url = "https://github.com/softprops/zig-envy/archive/refs/tags/v0.1.0.tar.gz",
            // 👇 hash verification
            //.hash = "",
        }
    }
}
```

> the hash below may vary. you can also depend any tag with `https://github.com/softprops/zig-envy/archive/refs/tags/v{version}.tar.gz` or current main with `https://github.com/softprops/zig-envy/archive/refs/heads/main/main.tar.gz`. to resolve a hash omit it and let zig tell you the expected value.

Add the following in your `build.zig` file

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});
    // 👇 de-reference envy dep from build.zig.zon
     const envy = b.dependency("envy", .{
        .target = target,
        .optimize = optimize,
    });
    var exe = b.addExecutable(.{
        .name = "your-exe",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    // 👇 add the envy module to executable
    exe.addModule("envy", envy.module("envy"));

    b.installArtifact(exe);
}
```

## 🥹 for budding ziglings

Does this look interesting but you're new to zig and feel left out? No problem, zig is young so most us of our new are as well. Here are some resources to help get you up to speed on zig

- [the official zig website](https://ziglang.org/)
- [zig's one-page language documentation](https://ziglang.org/documentation/0.11.0/)
- [ziglearn](https://ziglearn.org/)
- [ziglings exercises](https://github.com/ratfactor/ziglings)

\- softprops 2023
