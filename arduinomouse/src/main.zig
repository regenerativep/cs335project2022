const std = @import("std");

// https://github.com/MasterQ32/zig-serial/blob/master/src/serial.zig
const zig_serial = @import("zig_serial");

// X11
// https://tronche.com/gui/x/xlib/input/
// https://github.com/misusi/x11-keyboard-mouse-control/blob/master/xkbmouse.c
const c = @cImport({
    @cInclude("X.h");
    @cInclude("Xlib.h");
    @cInclude("extensions/XTest.h");
});

const mouse_sensitivity: f32 = 40;
const zone = 0.01;
const min_dist_when_pressed = 64;
const reset_mouse_x = 1920 / 2;
const reset_mouse_y = 1080 / 2;

const fname = "/dev/ttyACM0";
const display_name = ":0";

const Keycode = struct {
    pub const LMB = 1;
    pub const SCROLL_UP = 4;
    pub const SCROLL_DOWN = 5;
};

fn deadzone(val: f32, max: f32) f32 {
    if (std.math.fabs(val) < max) return 0;
    return val;
}
pub fn main() !void {
    // serial setup
    var serial = std.fs.openFileAbsolute(fname, .{ .mode = .read_write }) catch |e| {
        return std.log.err(
            "Failed to open \"{s}\" ({any}), is the arduino connected?",
            .{ fname, e },
        );
    };
    defer serial.close();
    try zig_serial.configureSerialPort(serial, zig_serial.SerialConfig{
        .baud_rate = 9600,
        .word_size = 8,
        .parity = .none,
        .stop_bits = .one,
        .handshake = .none,
    });

    // X11 setup
    var dpy = c.XOpenDisplay(display_name) orelse return error.DisplayOpenFailure;
    defer _ = c.XCloseDisplay(dpy);
    var root_window = c.XRootWindow(dpy, 0);
    defer _ = c.XDestroyWindow(dpy, root_window);

    var mouse_x: f32 = reset_mouse_x;
    var mouse_y: f32 = reset_mouse_y;
    var mouse_r: f32 = 0;
    var reader = serial.reader();
    var last_time = std.time.microTimestamp();
    var mouse_pressed = false;
    var press_loc_x = mouse_x;
    var press_loc_y = mouse_y;

    std.log.info("listening to arduino...", .{});
    while (true) {
        errdefer |e| std.log.err("Serial read failure ({any}). Arduino may have been disconnected.", .{e});
        switch (try reader.readByte()) {
            0 => { // cursor location update
                const current_time = std.time.microTimestamp();
                const delta = @intToFloat(f32, current_time - last_time) / std.time.us_per_s;
                last_time = current_time;
                const x = deadzone(@bitCast(f32, try reader.readIntLittle(u32)) * delta, zone);
                const y = deadzone(@bitCast(f32, try reader.readIntLittle(u32)) * delta, zone);
                const z = deadzone(@bitCast(f32, try reader.readIntLittle(u32)) * delta, zone);
                //std.log.info("x: {}, y: {}, z: {}\n", .{ x, y, z });

                mouse_r += x * (std.math.pi / 180.0);
                //std.log.info("r: {}\n", .{@floatToInt(i32, mouse_r * (180.0 / std.math.pi))});
                const cs = std.math.cos(mouse_r);
                const sn = std.math.sin(mouse_r);
                const nz = (z * cs) - (y * sn);
                const ny = (z * sn) + (y * cs);

                mouse_x -= nz * mouse_sensitivity;
                mouse_y -= ny * mouse_sensitivity;

                // only move if mouse is not pressed or the mouse has moved far enough
                // makes it easier to click on things
                if (!mouse_pressed or
                    (std.math.fabs(mouse_x - press_loc_x) > min_dist_when_pressed or
                    std.math.fabs(mouse_y - press_loc_y) > min_dist_when_pressed))
                {
                    mouse_pressed = false;
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
                }
            },
            1 => { // cursor reset
                mouse_x = reset_mouse_x;
                mouse_y = reset_mouse_y;
                mouse_r = 0;
            },
            2 => { // mouse press
                _ = c.XTestFakeButtonEvent(dpy, Keycode.LMB, c.True, c.CurrentTime);
                mouse_pressed = true;
                press_loc_x = mouse_x;
                press_loc_y = mouse_y;
                //std.log.info("mouse press", .{});
            },
            3 => { // mouse release
                _ = c.XTestFakeButtonEvent(dpy, Keycode.LMB, c.False, c.CurrentTime);
                mouse_pressed = false;
                //std.log.info("mouse release", .{});
            },
            4 => { // scroll up
                _ = c.XTestFakeButtonEvent(dpy, Keycode.SCROLL_UP, c.True, c.CurrentTime);
                _ = c.XTestFakeButtonEvent(dpy, Keycode.SCROLL_UP, c.False, c.CurrentTime);
            },
            5 => { // scroll down
                _ = c.XTestFakeButtonEvent(dpy, Keycode.SCROLL_DOWN, c.True, c.CurrentTime);
                _ = c.XTestFakeButtonEvent(dpy, Keycode.SCROLL_DOWN, c.False, c.CurrentTime);
            },
            else => return error.InvalidPacketId,
        }
    }
}
