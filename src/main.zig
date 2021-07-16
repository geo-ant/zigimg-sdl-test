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

    // const bitmap_texture  = sdl2.SDL_CreateTextureFromSurface(renderer,bitmap_surface);
    const bitmap_texture = (try sdlTextureFromData(renderer.?,& maybe_pixels.?,.{.w=bitmap.width(), .h = bitmap.height()},pixelmask));
    defer sdl2.SDL_DestroyTexture(bitmap_texture);
    if (bitmap_texture == null) {
        std.log.err("Could not create texture",.{});
    }
    const dst_rect = sdl2.SDL_Rect{.x=0,.y=0,.w=bitmap.width(),.h=bitmap.height()};

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

fn sdlTextureFromData(renderer: * sdl2.SDL_Renderer, storage : *const zigimg.color.ColorStorage, dims : Dimensions, pixelmask : PixelMask) ! ?*sdl2.SDL_Texture {
    const surface =  sdl2.SDL_CreateRGBSurfaceFrom(
        storage.Argb32.ptr,
        dims.w,
        dims.h,
        32,
        4*dims.w,
        pixelmask.red,
        pixelmask.green,
        pixelmask.blue,
        pixelmask.alpha);
    if(surface == null) {
        return error.CreateRgbSurface;
    }
    defer sdl2.SDL_FreeSurface(surface);

    var texture = sdl2.SDL_CreateTextureFromSurface(renderer,surface);
    if (texture == null) {
        return error.CreateTexture;
    }

    return texture;
}

const Dimensions = struct {
    w: i32, 
    h : i32
};

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
