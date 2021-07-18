const std = @import("std");
const c = @import("c.zig");
const zigimg = @import("zigimg");
const utils = @import("utils.zig");

pub fn main() anyerror!void {

    _= c.SDL_Init(c.SDL_INIT_VIDEO);
    defer c.SDL_Quit();

    var window = c.SDL_CreateWindow("Examples: zigimg with SDL2", c.SDL_WINDOWPOS_CENTERED, c.SDL_WINDOWPOS_CENTERED, 640, 480, 0);
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

    const bitmap_texture = textures[0];


    // var bitmap_image =  try zigimg.image.Image.fromFilePath(allocator, "assets/windows_rgba_v5.bmp");
    // defer bitmap_image.deinit();
    // const bitmap_texture = try utils.sdlTextureFromImage(renderer.?,bitmap_image);
    //defer c.SDL_DestroyTexture(bitmap_texture);

    const dst_rect = c.SDL_Rect{.x=0,.y=0,.w=@intCast(c_int,120),.h=@intCast(c_int,120)};

    var png_image =  try zigimg.image.Image.fromFilePath(allocator, "assets/png_image.png");
    defer png_image.deinit();
    const png_texture = try utils.sdlTextureFromImage(renderer,png_image);
    defer c.SDL_DestroyTexture(png_texture);

    const dst_rect2 = c.SDL_Rect{.x=dst_rect.w,.y=0,.w=@intCast(c_int,png_image.width),.h=@intCast(c_int,png_image.height)};

    mainloop: while (true) {
        var sdl_event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&sdl_event) != 0) {
            switch (sdl_event.type) {
                c.SDL_QUIT => break :mainloop,
                else => {},
            }
        }

        _ = c.SDL_SetRenderDrawColor(renderer, 0xff, 0xff, 0xff, 0xff);
        _ = c.SDL_RenderClear(renderer);
        _ = c.SDL_RenderCopy(renderer, bitmap_texture,null,&dst_rect);
        _ = c.SDL_RenderCopy(renderer, png_texture, null, &dst_rect2);
        c.SDL_RenderPresent(renderer);
    }

    std.log.info("All your codebase are belong to us.", .{});
}