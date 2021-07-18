const std = @import("std");

const c = @import("c.zig");
const zigimg = @import("zigimg");

pub fn main() anyerror!void {

    _= c.SDL_Init(c.SDL_INIT_VIDEO);
    defer c.SDL_Quit();

    var window = c.SDL_CreateWindow("Examples: zigimg with SDL2", c.SDL_WINDOWPOS_CENTERED, c.SDL_WINDOWPOS_CENTERED, 640, 480, 0);
    defer c.SDL_DestroyWindow(window);

    var renderer = c.SDL_CreateRenderer(window, 0, c.SDL_RENDERER_PRESENTVSYNC);
    defer c.SDL_DestroyRenderer(renderer);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _=gpa.deinit();
    var allocator : *std.mem.Allocator = &gpa.allocator;

    var bitmap_image =  try zigimg.image.Image.fromFilePath(allocator, "assets/windows_rgba_v5.bmp");
    defer bitmap_image.deinit();
    const bitmap_texture = try sdlTextureFromImage(renderer.?,bitmap_image);
    defer c.SDL_DestroyTexture(bitmap_texture);

    const dst_rect = c.SDL_Rect{.x=0,.y=0,.w=@intCast(c_int,bitmap_image.width),.h=@intCast(c_int,bitmap_image.height)};

    var png_image =  try zigimg.image.Image.fromFilePath(allocator, "assets/png_image.png");
    defer png_image.deinit();
    const png_texture = try sdlTextureFromImage(renderer.?,png_image);
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


fn sdlTextureFromImage(renderer: * c.SDL_Renderer, image : zigimg.image.Image) ! ?*c.SDL_Texture {
    
    const pxinfo = try PixelInfo.from(image);
    // if I don't do the trick with breaking inside the switch,
    // then it says, the return value of the switch is ignored,
    // which seems strange to me...    
    // TODO: ask about this on the discord... 
    const data : *c_void = blk: {if (image.pixels) |storage| {
        switch(storage) {
            .Argb32 => |argb32| break :blk @ptrCast(*c_void,argb32.ptr),
            .Rgb24 => |rgb24| break :blk @ptrCast(*c_void,rgb24.ptr),
            else => return error.InvalidColorStorage,
        }
    } else {
        return error.EmptyColorStorage;
    }};
    //const data : ?*c_void = image.pixels.?.Argb32.ptr;

    const surface =  c.SDL_CreateRGBSurfaceFrom(
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
    defer c.SDL_FreeSurface(surface);

    var texture = c.SDL_CreateTextureFromSurface(renderer,surface);
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

