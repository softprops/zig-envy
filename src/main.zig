const std = @import("std");
const testing = std.testing;

pub const Error = error{
    TypeMismatch,
    StructFieldMissing,
    Unimplemented,
};

/// parses env variables into a struct type
///
/// The provided T must be a struct type.
///
/// env variables are assumed to be SCREAMING_SNAKE_CASE version ofs of zigs conventional snake_case field names
pub fn fromEnv(comptime T: type, allocator: std.mem.Allocator) !T {
    const env = try std.process.getEnvMap(allocator);
    defer env.deinit();
    return try fromHashMap(T, env.hashmap, allocator);
}

fn fromHashMap(comptime T: type, env: std.StringHashMap([]const u8), allocator: std.mem.Allocator) !T {
    const struct_info = @typeInfo(T).Struct;
    var parsed: T = undefined;
    inline for (struct_info.fields) |field| {
        const value = env.get(field.name) orelse blk: {
            const field_name = try std.ascii.allocUpperString(allocator, field.name);
            defer allocator.free(field_name);
            break :blk env.get(field_name);
        };

        if (@typeInfo(field.type) == .Optional) {
            @field(parsed, field.name) = try parseOptional(field.type, value, allocator);
            continue;
        }

        if (value) |unwrapped| {
            @field(parsed, field.name) = try parseValue(field.type, unwrapped, allocator);
        } else if (field.default_value) |dvalue| {
            const dvalue_aligned: *align(field.alignment) const anyopaque = @alignCast(dvalue);
            @field(parsed, field.name) = @as(*const field.type, @ptrCast(dvalue_aligned)).*;
        } else {
            std.debug.print("missing struct field: {s}: {s}", .{ field.name, @typeName(field.type) });
            return error.StructFieldMissing;
        }
    }

    return parsed;
}

fn parseOptional(comptime T: type, value: ?[]const u8, allocator: std.mem.Allocator) Error!T {
    const unwrapped = value orelse return null;
    const opt_info = @typeInfo(T).Optional;
    return @as(T, try parseValue(opt_info.child, unwrapped, allocator));
}

fn parseValue(comptime T: type, value: []const u8, allocator: std.mem.Allocator) !T {
    return switch (@typeInfo(T)) {
        .Int => try std.fmt.parseInt(T, value, 10),
        .Pointer => parsePointer(T, value, allocator),
        else => error.Unimplemented,
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

test "from hash map" {
    var allocator = std.testing.allocator;
    const Test = struct { int: u32, str: []const u8, opt: ?[]const u8 = null, default: []const u8 = "default" };
    var env = std.StringHashMap([]const u8).init(allocator);
    defer env.deinit();
    try env.put("INT", "1");
    try env.put("STR", "str");
    try env.put("BOOLEAN", "true");
    try std.testing.expect(std.meta.eql(Test{ .int = 1, .str = "str" }, try fromHashMap(Test, env, allocator)));
}
