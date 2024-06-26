//! deserialize environment variables into typesafe structs
const std = @import("std");
const testing = std.testing;

const log = std.log.scoped(.envy);

/// Possible errors
pub const Error = error{
    /// Missing an env var for a given struct field
    StructFieldMissing,
    /// A value that does not align with one defined for a given field
    InvalidValue,
    /// Attempting to parse into an invalid type (must be a struct type)
    InvalidType,
    /// A value type not yet implemented
    Unimplemented,
};

/// envy env parsing options
pub const EnvOptions = struct {
    /// env var prefix to strip from env var names when
    /// resolving env vars
    ///
    /// example
    ///
    /// ```
    /// const config = try env.fromEnv(MyConfig, .{ .prefix = "MY_APP_"});
    /// ```
    prefix: ?[]const u8 = null,
};

/// parses env variables into a struct type
///
/// The provided T must be a struct type.
///
/// env variables are assumed to be SCREAMING_SNAKE_CASE version ofs of zigs conventional snake_case field names
///
/// example
///
///```zig
/// const std = @import("std");
/// const envy = @import("envy");
///
/// const Config = struct {
///     foo: u16,
///     bar: bool,
///     baz: []const u8,
///     boom: ?u64,
/// };
///
/// pub fn main() !void {
///     var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
///     defer arena.deinit();
///     const allocator = arena.allocator();
///
///     const config = envy.parse(Config, allocator, .{}) catch |err| {
///         std.debug.print("error parsing config from env: {any}", err);
///         return;
///     };
///     std.debug.println("config {any}", .{ config });
/// }
///```
pub fn parse(comptime T: type, allocator: std.mem.Allocator, options: EnvOptions) !T {
    var env = try std.process.getEnvMap(allocator);
    defer env.deinit();

    var copy = std.StringHashMap([]const u8).init(allocator);
    defer copy.deinit();
    var it = env.iterator();
    while (it.next()) |entry| {
        try copy.put(entry.key_ptr.*, entry.value_ptr.*);
    }

    return try fromHashMap(T, copy, allocator, options);
}

fn fromHashMap(
    comptime T: type,
    env: std.StringHashMap([]const u8),
    allocator: std.mem.Allocator,
    options: EnvOptions,
) !T {
    const info = @typeInfo(T);
    switch (info) {
        .Struct => |struct_info| {
            var parsed: T = undefined;
            inline for (struct_info.fields) |field| {
                const field_name = try std.ascii.allocUpperString(allocator, field.name);
                defer allocator.free(field_name);
                const prefixed = try std.fmt.allocPrint(
                    allocator,
                    "{s}{s}",
                    .{ options.prefix orelse "", field_name },
                );
                defer allocator.free(prefixed);
                const value = env.get(prefixed);

                if (@typeInfo(field.type) == .Optional) {
                    @field(parsed, field.name) = try parseOptional(
                        field.type,
                        value,
                        allocator,
                    );
                    continue;
                }

                if (value) |unwrapped| {
                    @field(parsed, field.name) = try parseValue(
                        field.type,
                        unwrapped,
                        allocator,
                    );
                } else if (field.default_value) |dvalue| {
                    const dvalue_aligned: *align(field.alignment) const anyopaque = @alignCast(dvalue);
                    @field(parsed, field.name) = @as(*const field.type, @ptrCast(dvalue_aligned)).*;
                } else {
                    log.debug("missing struct field: '{s}'", .{field.name});
                    return error.StructFieldMissing;
                }
            }

            return parsed;
        },
        else => return error.InvalidType,
    }
}

fn parseOptional(comptime T: type, value: ?[]const u8, allocator: std.mem.Allocator) !T {
    const unwrapped = value orelse return null;
    const opt_info = @typeInfo(T).Optional;
    return @as(T, try parseValue(
        opt_info.child,
        unwrapped,
        allocator,
    ));
}

const BOOLS = std.StaticStringMap(bool).initComptime(
    .{
        .{ "true", true },
        .{ "1", true },
        .{ "false", false },
        .{ "0", false },
    },
);

fn parseValue(comptime T: type, value: []const u8, allocator: std.mem.Allocator) !T {
    return switch (@typeInfo(T)) {
        .Int => try std.fmt.parseInt(T, value, 10),
        .Float => try std.fmt.parseFloat(T, value),
        .Pointer => parsePointer(T, value, allocator),
        .Bool => BOOLS.get(value) orelse error.InvalidValue,
        .Enum => |info| {
            inline for (info.fields, 0..) |field, i| {
                if (std.mem.eql(u8, field.name, value)) {
                    return @enumFromInt(i);
                }
            }
            return error.InvalidValue;
        },
        else => {
            log.err("value type {any} not supported", .{T});
            return error.Unimplemented;
        },
    };
}

fn parsePointer(comptime T: type, value: []const u8, allocator: std.mem.Allocator) !T {
    const ptr_info = @typeInfo(T).Pointer;
    switch (ptr_info.size) {
        .Slice => {
            if (ptr_info.child == u8) {
                return value;
            }

            var parsed = try allocator.alloc(ptr_info.child, value.len);
            for (value, 0..) |elem, i| {
                parsed[i] = try parseValue(ptr_info.child, elem);
            }
            return parsed;
        },
        else => return error.Unimplemented,
    }
}

test "struct not provided" {
    const allocator = std.testing.allocator;
    var env = std.StringHashMap([]const u8).init(allocator);
    defer env.deinit();
    try std.testing.expect(error.InvalidType == fromHashMap(
        u8,
        env,
        allocator,
        .{},
    ));
}

test "from hash map" {
    const allocator = std.testing.allocator;
    const Enum = enum { foo, bar };
    const Test = struct {
        int: u32,
        str: []const u8,
        boolean: bool,
        enummy: Enum,
        float: f16,
        opt: ?[]const u8 = null,
        default: []const u8 = "default",
    };
    var env = std.StringHashMap([]const u8).init(allocator);
    defer env.deinit();
    try env.put("APP_INT", "1");
    try env.put("APP_STR", "str");
    try env.put("APP_BOOLEAN", "true");
    try env.put("APP_FLOAT", "1.0");
    try env.put("APP_ENUMMY", "bar");
    try std.testing.expect(std.meta.eql(Test{
        .boolean = true,
        .int = 1,
        .float = 1.0,
        .str = "str",
        .enummy = Enum.bar,
    }, try fromHashMap(
        Test,
        env,
        allocator,
        .{ .prefix = "APP_" },
    )));
}
