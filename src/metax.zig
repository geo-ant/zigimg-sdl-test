const std = @import("std");

/// unwrap an optional or throw the given error type
pub fn unwrap(optional : anytype, err: anyerror) !@TypeOf(optional.?) {
    if (optional) |value| {
        return value;
    } else {
        return err;
    }
}