/// Build configuration that affects `zig build`.
/// It's main purpose is to store the selected
/// app runtime to determine whether a full
/// application or just the static library
/// is built on subsequent steps.
const Config = @This();

const std = @import("std");
const AppRuntime = @import("../apprt/runtime.zig").Runtime;

app_runtime: AppRuntime = .none,
optimize: std.lang.Optimize,
target: std.Build.ResolvedTarget,

pub fn init(b: *std.Build) Config {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    var config: Config = .{
        .target = target,
        .optimize = optimize,
    };

    // Provides -Dapprt option. By default, `zig build` will use whatever
    // the machine's OS is. Can be explcitily set otherwise.
    config.app_runtime = b.option(
        AppRuntime,
        "apprt",
        "The runtime of the app to use. Determines whether a library or full windowed application is built",
    ) orelse AppRuntime.default(target.result);

    return config;
}
