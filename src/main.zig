const std = @import("std");

const sdl2 = @cImport(@cInclude("SDL.h"));
const zigimg = @import("zigimg");

pub fn main() anyerror!void {

    _= sdl2.SDL_Init(sdl2.SDL_INIT_VIDEO);
    defer sdl2.SDL_Quit();

    var window = sdl2.SDL_CreateWindow("Examples: zigimg with SDL2", sdl2.SDL_WINDOWPOS_CENTERED, sdl2.SDL_WINDOWPOS_CENTERED, 640, 480, 0);
    defer sdl2.SDL_DestroyWindow(window);

    var renderer = sdl2.SDL_CreateRenderer(window, 0, sdl2.SDL_RENDERER_PRESENTVSYNC);
    defer sdl2.SDL_DestroyRenderer(renderer);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _=gpa.deinit();
    var allocator : *std.mem.Allocator = &gpa.allocator;
    var image_file = try openFile(allocator, "assets/windows_rgba_v5.bmp");
    defer image_file.close();

    var stream_source = std.io.StreamSource{.file = image_file};
    var maybe_pixels: ?zigimg.color.ColorStorage = null; 
    defer {
        if (maybe_pixels) |pixels| {
            pixels.deinit(allocator);
        }
    }

    var bitmap = zigimg.bmp.Bitmap{};
    try bitmap.read(allocator, stream_source.reader(), stream_source.seekableStream(), &maybe_pixels);
    std.log.info("Bitmap Dimensions: {} x {}", .{bitmap.width(), bitmap.height()});
    std.log.info("Bitmap Pixel Format: {}", .{bitmap.pixel_format});


    switch(maybe_pixels.?) {
        .Argb32 => {
            std.log.info("Color Storage is Argb32 format", .{});
        },
        else => {
            std.log.err("Unexpected color format!!", .{});
        }
    }

    // see SDL2 docs https://wiki.libsdl.org/SDL_CreateRGBSurfaceFrom
    const pixelmask = try extractPixelmask(&bitmap);
    std.log.info("pixel pointer address is {*}", .{&maybe_pixels});
    std.log.info("Color Storage Slice len is {} (expected {})", .{maybe_pixels.?.len(), bitmap.width()*bitmap.height()});

    // this is hardcoded for 32bit rgba format. We could easily query for 24bit rgb here. See
    // also the docs https://wiki.libsdl.org/SDL_CreateRGBSurfaceFrom
    const bitmap_surface =  sdl2.SDL_CreateRGBSurfaceFrom(
        maybe_pixels.?.Argb32.ptr,
        bitmap.width(),
        bitmap.height(),
        32,
        4*bitmap.width(),
        pixelmask.red,
        pixelmask.green,
        pixelmask.blue,
        pixelmask.alpha);

    defer sdl2.SDL_FreeSurface(bitmap_surface);
    if(bitmap_surface == null) {
        std.log.err("Could not create bitmap surface.", .{});
    }

    const bitmap_texture  = sdl2.SDL_CreateTextureFromSurface(renderer,bitmap_surface);
    defer sdl2.SDL_DestroyTexture(bitmap_texture);
    if (bitmap_texture == null) {
        std.log.err("Could not create texture",.{});
    }
    const dst_rect = sdl2.SDL_Rect{.x=0,.y=0,.w=bitmap_surface.*.w,.h=bitmap_surface.*.h};

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
        _ = sdl2.SDL_RenderCopy(renderer, bitmap_texture,null,&dst_rect);
        sdl2.SDL_RenderPresent(renderer);
    }

    std.log.info("All your codebase are belong to us.", .{});
}

fn sdlTextureFromData(storage : *const zigimg.color.ColorStorage) !sdl2.SDL_Texture {
    _ = storage;

    return dong;
}

// helper structure for getting the pixelmasks out of an image
const PixelMask = struct {
    red : u32,
    green : u32,
    blue : u32,
    alpha : u32,
};

fn extractPixelmask(bmp : *const zigimg.bmp.Bitmap) !PixelMask {
    switch(bmp.*.infoHeader) {
        .V4 => |header| return PixelMask{.red = header.redMask, .green = header.greenMask, .blue = header.blueMask, .alpha = header.alphaMask},
        .V5 => |header| return PixelMask{.red = header.redMask, .green = header.greenMask, .blue = header.blueMask, .alpha = header.alphaMask},
        else => return error.InvalidHeader,
    }
}

fn openFile(allocator : *std.mem.Allocator, relative_path : [] const u8) !std.fs.File {
    var resolved_path = try std.fs.path.resolve(allocator, &[_][]const u8{relative_path});
    defer allocator.free(resolved_path);
    return std.fs.cwd().openFile(resolved_path, .{});
}
