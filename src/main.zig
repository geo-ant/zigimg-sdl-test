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
    var bmp_file = try openFile(allocator, "assets/windows_rgba_v5.bmp");
    defer bmp_file.close();

    var stream_source = std.io.StreamSource{.file = bmp_file};
    var maybe_bmp_pixels: ?zigimg.color.ColorStorage = null; 
    defer {
        if (maybe_bmp_pixels) |pixels| {
            pixels.deinit(allocator);
        }
    }

    var bitmap = zigimg.bmp.Bitmap{};
    try bitmap.read(allocator, stream_source.reader(), stream_source.seekableStream(), &maybe_bmp_pixels);
    std.log.info("Bitmap Dimensions: {} x {}", .{bitmap.width(), bitmap.height()});
    std.log.info("Bitmap Pixel Format: {}", .{bitmap.pixel_format});

    switch(maybe_bmp_pixels.?) {
        .Argb32 => {
            std.log.info("Color Storage is Argb32 format", .{});
        },
        else => {
            std.log.err("Unexpected color format!!", .{});
        }
    }

    // see SDL2 docs https://wiki.libsdl.org/SDL_CreateRGBSurfaceFrom
    const pixelmask = try extractPixelmask(&bitmap);
    std.log.info("pixel pointer address is {*}", .{&maybe_bmp_pixels});
    std.log.info("Color Storage Slice len is {} (expected {})", .{maybe_bmp_pixels.?.len(), bitmap.width()*bitmap.height()});

    // const bitmap_texture  = sdl2.SDL_CreateTextureFromSurface(renderer,bitmap_surface);
    const bitmap_texture = (try sdlTextureFromData(renderer.?,& maybe_bmp_pixels.?,.{.w=bitmap.width(), .h = bitmap.height()},pixelmask));
    defer sdl2.SDL_DestroyTexture(bitmap_texture);
    if (bitmap_texture == null) {
        std.log.err("Could not create texture",.{});
    }
    const dst_rect = sdl2.SDL_Rect{.x=0,.y=0,.w=bitmap.width(),.h=bitmap.height()};

    // var png_file = try openFile(allocator, "assets/png_image.png");
    // defer png_file.close();

    // stream_source = std.io.StreamSource{.file = png_file};
    // var png = zigimg.png.PNG.init(allocator);
    // defer png.deinit();

    // var maybe_png_pixels: ?zigimg.color.ColorStorage = null; 
    // defer {
    //     if (maybe_png_pixels) |pixels| {
    //         pixels.deinit(allocator);
    //     }
    // }


    // try png.read(stream_source.reader(), stream_source.seekableStream(), &maybe_png_pixels);
    // const png_texture = (try sdlTextureFromData(renderer.?,& maybe_png_pixels.?,.{.w=@intCast(i32,png.header.width), .h = @intCast(i32,png.header.height)},pixelmask));

    var png_image =  try zigimg.image.Image.fromFilePath(allocator, "assets/windows_rgba_v5.bmp");
    const png_texture = try sdlTextureFromImage(renderer.?,png_image);
    defer sdl2.SDL_DestroyTexture(png_texture);


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
        _ = sdl2.SDL_RenderCopy(renderer, png_texture, null, &dst_rect);
        sdl2.SDL_RenderPresent(renderer);
    }

    std.log.info("All your codebase are belong to us.", .{});
}

const ImgData = struct {
    data_ptr : *c_void,
    bits : i32,
    pitch : i32,

    fn init(storage : * zigimg.color.ColorStorage, img_width : i32 ) !@This() {
         switch (storage.*) {
             .Argb32 => |argb32|{
                 return @This(){.data_ptr = argb32.ptr, .bits = 32, .pitch = 4*img_width };
             },
             .Rgb24 => |rgb24| {
                 return @This(){.data_ptr = rgb24.ptr, .bits = 24, .pitch = 3*img_width };
             },
             else => {
                 return error.InvalidColorStorage;
             }
         }
    }
};


fn sdlTextureFromData(renderer: * sdl2.SDL_Renderer, storage : *zigimg.color.ColorStorage, dims : Dimensions, pixelmask : PixelMask) ! ?*sdl2.SDL_Texture {
    
    const img = try ImgData.init(storage,dims.w);

    const surface =  sdl2.SDL_CreateRGBSurfaceFrom(
        img.data_ptr,
        dims.w,
        dims.h,
        img.bits,
        img.pitch,
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

fn unwrap(optional : anytype) !@TypeOf(optional.?) {
    if (optional) |value| {
        return value;
    } else {
        return error.EmptyOptionalUnwrap;
    }
}

const PixelInfo = struct {
    bits : i32,
    pitch : i32,
    pixelmask : PixelMask,

    const Self = @This();

    pub fn from(image : zigimg.image.Image) !Self {
        const Sizes = struct {bits : u32, pitch : usize};
        const sizes : Sizes = switch( try unwrap(image.pixels) ) {
            .Argb32 =>  Sizes{.bits = 32, .pitch= 4*image.width},
            .Rgb24 =>   Sizes{.bits = 24,  .pitch = 3*image.width},
            else => return error.InvalidColorStorage,
        };
        return Self {
            .bits = @intCast(i32,sizes.bits),
            .pitch = @intCast(i32,sizes.pitch),
            .pixelmask = try PixelMask.fromColorStorage(try unwrap(image.pixels))
        };
    }

};


fn sdlTextureFromImage(renderer: * sdl2.SDL_Renderer, image : zigimg.image.Image) ! ?*sdl2.SDL_Texture {
    


    const pxinfo = try PixelInfo.from(image);

    // const data : *c_void = if (image.pixels) |storage| {
    //     switch(storage) {
    //         .Argb32 => |argb32| @ptrCast(*c_void,argb32.ptr),
    //         .Rgb24 => |rgb24| @ptrCast(*c_void,rgb24.ptr),
    //         else => return error.InvalidColorStorage,
    //     }
    // } else {
    //     return error.EmptyColorStorage;
    // };
    const data : ?*c_void = image.pixels.?.Argb32.ptr;

    const surface =  sdl2.SDL_CreateRGBSurfaceFrom(
        data,
        @intCast(c_int,image.width),
        @intCast(c_int,image.height),
        pxinfo.bits,
        pxinfo.pitch,
        pxinfo.pixelmask.red,
        pxinfo.pixelmask.green,
        pxinfo.pixelmask.blue,
        pxinfo.pixelmask.alpha);
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

    const Self = @This();

    pub fn fromColorStorage(storage : zigimg.color.ColorStorage) !Self {
        switch(storage) {
            .Argb32 => return Self {
                .red   = 0x00ff0000,
                .green = 0x0000ff00,
                .blue  = 0x000000ff,
                .alpha = 0xff000000,
                },
            .Rgb24 => return Self {
                .red   = 0xff0000,
                .green = 0x00ff00,
                .blue  = 0x0000ff,
                .alpha = 0,
                },
            else => return error.InvalidColorStorage,
        }
    }
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
