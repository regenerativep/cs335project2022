# arduino mouse

works only on X11 linux as of writing.


use arduino ide to upload `arduinomousec` to the arduino. make sure serial monitor is off.

`zig build run` in the `arduinomouse` folder. once connected to the arduino, should make pointer move around. you might need to mess with the reset mouse position and the screen and sensitivity values.

zig code depends on [zig-serial](https://github.com/MasterQ32/zig-serial/)
