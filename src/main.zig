const std = @import("std");

const sdl2 = @cImport(@cInclude("SDL.h"));

pub fn main() anyerror!void {

    _= sdl2.SDL_Init(sdl2.SDL_INIT_VIDEO);
    defer sdl2.SDL_Quit();

        var window = sdl2.SDL_CreateWindow("hello gamedev", sdl2.SDL_WINDOWPOS_CENTERED, sdl2.SDL_WINDOWPOS_CENTERED, 640, 400, 0);
    defer sdl2.SDL_DestroyWindow(window);

    var renderer = sdl2.SDL_CreateRenderer(window, 0, sdl2.SDL_RENDERER_PRESENTVSYNC);
    defer sdl2.SDL_DestroyRenderer(renderer);

    var frame: usize = 0;
    mainloop: while (true) {
        var sdl_event: sdl2.SDL_Event = undefined;
        while (sdl2.SDL_PollEvent(&sdl_event) != 0) {
            switch (sdl_event.type) {
                sdl2.SDL_QUIT => break :mainloop,
                else => {},
            }
        }

        _ = sdl2.SDL_SetRenderDrawColor(renderer, 0xff, 0xff, 0xff, 0xff);
        _ = sdl2.SDL_RenderClear(renderer);
        var rect = sdl2.SDL_Rect{ .x = 0, .y = 0, .w = 60, .h = 60 };
        const a = 0.06 * @intToFloat(f32, frame);
        const t = 2 * std.math.pi / 3.0;
        const r = 100 * @cos(0.1 * a);
        rect.x = 290 + @floatToInt(i32, r * @cos(a));
        rect.y = 170 + @floatToInt(i32, r * @sin(a));
        _ = sdl2.SDL_SetRenderDrawColor(renderer, 0xff, 0, 0, 0xff);
        _ = sdl2.SDL_RenderFillRect(renderer, &rect);
        rect.x = 290 + @floatToInt(i32, r * @cos(a + t));
        rect.y = 170 + @floatToInt(i32, r * @sin(a + t));
        _ = sdl2.SDL_SetRenderDrawColor(renderer, 0, 0xff, 0, 0xff);
        _ = sdl2.SDL_RenderFillRect(renderer, &rect);
        rect.x = 290 + @floatToInt(i32, r * @cos(a + 2 * t));
        rect.y = 170 + @floatToInt(i32, r * @sin(a + 2 * t));
        _ = sdl2.SDL_SetRenderDrawColor(renderer, 0, 0, 0xff, 0xff);
        _ = sdl2.SDL_RenderFillRect(renderer, &rect);
        sdl2.SDL_RenderPresent(renderer);
        frame += 1;
    }

    std.log.info("All your codebase are belong to us.", .{});
}
