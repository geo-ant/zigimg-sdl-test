const c = @import("c.zig");
const std = @import("std");
const zigimg = @import("zigimg");
const unwrap = @import("metax.zig").unwrap;
const Allocator = std.mem.Allocator;

pub fn sdlTextureFromImage(renderer: * c.SDL_Renderer, image : zigimg.image.Image) ! ?*c.SDL_Texture {
    
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


const PixelInfo = struct {
    bits : c_int,
    pitch : c_int,
    pixelmask : PixelMask,

    const Self = @This();

    pub fn from(image : zigimg.image.Image) !Self {
        const Sizes = struct {bits : c_int, pitch : c_int};
        const sizes : Sizes = switch( try unwrap(image.pixels, error.EmptyColorStorage) ) {
            .Argb32 =>  Sizes{.bits = 32, .pitch= 4*@intCast(c_int,image.width)},
            .Rgb24 =>   Sizes{.bits = 24,  .pitch = 3*@intCast(c_int,image.width)},
            else => return error.InvalidColorStorage,
        };
        return Self {
            .bits = @intCast(c_int,sizes.bits),
            .pitch = @intCast(c_int,sizes.pitch),
            .pixelmask = try PixelMask.fromColorStorage(try unwrap(image.pixels, error.EmptyColorStorage))
        };
    }

};

// helper structure for getting the pixelmasks out of an image
const PixelMask = struct {
    red : u32,
    green : u32,
    blue : u32,
    alpha : u32,

    const Self = @This();
    /// construct a pixelmask given the colorstorage.
    /// *Attention*: right now only works for 24bit RGB and 32bit ARGB storage.
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


pub fn openImagesFromDirectoryRelPath(allocator : *std.mem.Allocator, dir_path : [] const u8) ! []zigimg.image.Image {
    _ = allocator;
    _ = dir_path;

    var array_list = std.ArrayList(zigimg.image.Image).init(allocator);
    defer array_list.deinit();

    const dir = try std.fs.cwd().openDir(dir_path, .{.iterate = true});
    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind == .File) {
            var file = try dir.openFile(entry.name,.{});
            try array_list.append(try zigimg.image.Image.fromFile(allocator,&file));
        }
    }

    return array_list.toOwnedSlice();
}
