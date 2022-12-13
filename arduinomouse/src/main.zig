const std = @import("std");
const zig_serial = @import("zig_serial");
const c = @cImport({
    @cInclude("X.h");
    @cInclude("Xlib.h");
});

fn deadzone(val: f32, max: f32) f32 {
    if (std.math.fabs(val) < max) return 0;
    return val;
}
pub fn main() !void {
    var stdout = std.io.getStdOut();
    var serial = try std.fs.openFileAbsolute("/dev/ttyACM0", .{ .mode = .read_write });
    defer serial.close();

    try zig_serial.configureSerialPort(serial, zig_serial.SerialConfig{
        .baud_rate = 9600,
        .word_size = 8,
        .parity = .none,
        .stop_bits = .one,
        .handshake = .none,
    });

    // X11. https://stackoverflow.com/questions/2433447/how-to-set-mouse-cursor-position-in-c-on-linux
    var dpy = c.XOpenDisplay(":0") orelse return error.DisplayOpenFailure;
    defer _ = c.XCloseDisplay(dpy);
    var root_window = c.XRootWindow(dpy, 0);
    defer _ = c.XDestroyWindow(dpy, root_window);

    var mouse_x: f32 = 1680 + (1920 / 2);
    var mouse_y: f32 = 1080 / 2;
    var mouse_r: f32 = 0;
    try stdout.writeAll("listening...\n");
    var reader = serial.reader();
    var last_time = std.time.microTimestamp();
    while (true) {
        switch (try reader.readByte()) {
            0 => {
                const current_time = std.time.microTimestamp();
                const delta = @intToFloat(f32, current_time - last_time) / std.time.us_per_s;
                last_time = current_time;
                const mouse_sensitivity: f32 = 100;
                const zone = 0.01;
                const x = deadzone(@bitCast(f32, try reader.readIntLittle(u32)) * delta, zone);
                const y = deadzone(@bitCast(f32, try reader.readIntLittle(u32)) * delta, zone);
                const z = deadzone(@bitCast(f32, try reader.readIntLittle(u32)) * delta, zone);
                //try stdout.writer().print("x: {}, y: {}, z: {}\n", .{ x, y, z });

                mouse_r += x * (std.math.pi / 180.0);
                try stdout.writer().print("r: {}\n", .{@floatToInt(i32, mouse_r * (180.0 / std.math.pi))});
                const cs = std.math.cos(mouse_r);
                const sn = std.math.sin(mouse_r);
                const nz = (z * cs) - (y * sn);
                const ny = (z * sn) + (y * cs);

                mouse_x -= nz * mouse_sensitivity;
                mouse_y -= ny * mouse_sensitivity;
                _ = c.XSelectInput(dpy, root_window, c.KeyReleaseMask);
                _ = c.XWarpPointer(
                    dpy,
                    c.None,
                    root_window,
                    0,
                    0,
                    0,
                    0,
                    @floatToInt(c_int, mouse_x),
                    @floatToInt(c_int, mouse_y),
                );
                _ = c.XFlush(dpy);
            },
            1 => {
                mouse_x = 1680 + (1920 / 2);
                mouse_y = 1080 / 2;
                mouse_r = 0;
            },
            else => return error.InvalidPacketId,
        }
    }
}
