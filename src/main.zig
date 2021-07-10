const std = @import("std");

const sdl2 = @cImport(@cInclude("SDL.h"));
const zigimg = @import("zigimg");

pub fn main() anyerror!void {

    _= sdl2.SDL_Init(sdl2.SDL_INIT_VIDEO);
    defer sdl2.SDL_Quit();

    var window = sdl2.SDL_CreateWindow("hello gamedev", sdl2.SDL_WINDOWPOS_CENTERED, sdl2.SDL_WINDOWPOS_CENTERED, 640, 480, 0);
    defer sdl2.SDL_DestroyWindow(window);

    var renderer = sdl2.SDL_CreateRenderer(window, 0, sdl2.SDL_RENDERER_PRESENTVSYNC);
    defer sdl2.SDL_DestroyRenderer(renderer);

    const image_surface = sdl2.SDL_LoadBMP("assets/logo.bmp");
    defer sdl2.SDL_FreeSurface(image_surface);
    if(image_surface == null) {
            std.log.info("Could not load image.", .{});
    }
    const texture  = sdl2.SDL_CreateTextureFromSurface(renderer,image_surface);
    defer sdl2.SDL_DestroyTexture(texture);
    if(texture == null) {
        std.log.info("Could not generate texture from surface",.{});
    }

    var the_bitmap = zigimg.bmp.Bitmap{};

    const dst_rect = sdl2.SDL_Rect{.x=0,.y=0,.w=@divFloor(image_surface.*.w,2),.h=@divFloor(image_surface.*.h,2)};

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
        _ = sdl2.SDL_RenderCopy(renderer, texture,null,&dst_rect);
        sdl2.SDL_RenderPresent(renderer);
    }

    std.log.info("All your codebase are belong to us.", .{});
}
