const std = @import("std");
const c = @import("c.zig");
const zigimg = @import("zigimg");
const utils = @import("utils.zig");

pub fn main() anyerror!void {

    _= c.SDL_Init(c.SDL_INIT_VIDEO);
    defer c.SDL_Quit();

    // edge length of the square window
    const WINDOW_SIZE :c_int = 640;

    var window = c.SDL_CreateWindow("Examples: zigimg with SDL2", c.SDL_WINDOWPOS_CENTERED, c.SDL_WINDOWPOS_CENTERED, WINDOW_SIZE, WINDOW_SIZE, 0);
    defer c.SDL_DestroyWindow(window);

    var renderer = c.SDL_CreateRenderer(window, 0, c.SDL_RENDERER_PRESENTVSYNC) orelse return error.CreateRenderer;
    defer c.SDL_DestroyRenderer(renderer);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _=gpa.deinit();
    var allocator : *std.mem.Allocator = &gpa.allocator;

    const images = try utils.openImagesFromDirectoryRelPath(allocator, "assets");
    defer {
        for (images) |image| {
            image.deinit();
        }
        allocator.free(images);
    }

    var textures = try utils.sdlTexturesFromImagesAlloc(allocator,renderer,images);
    defer {
        for (textures) |texture| {
            c.SDL_DestroyTexture(texture);
        }
        allocator.free(textures);
    }

    _ = c.SDL_SetRenderDrawColor(renderer, 0x80, 0x80, 0x80, 0x00);
    _ = c.SDL_RenderClear(renderer);

    const TILES_PER_ROW = @floatToInt(c_int,@ceil(@sqrt(@intToFloat(f32,textures.len))));
    const TILE_SIZE = @intCast(c_int,@divFloor(WINDOW_SIZE,TILES_PER_ROW));

    var destination_rect = c.SDL_Rect{.x = 0, .y = 0, .w = TILE_SIZE, .h = TILE_SIZE};
    for (textures) |texture,idx| {
        _ = c.SDL_RenderCopy(renderer, texture,null,&destination_rect);
        destination_rect.x += TILE_SIZE;
        if (@mod(@intCast(c_int,idx),TILES_PER_ROW)==0) {
            destination_rect.y += TILE_SIZE;
            destination_rect.x = 0;
        }
    }
    c.SDL_RenderPresent(renderer);

    mainloop: while (true) {
        var sdl_event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&sdl_event) != 0) {
            switch (sdl_event.type) {
                c.SDL_QUIT => break :mainloop,
                else => {},
            }
        }
    }
}