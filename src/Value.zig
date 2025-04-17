const GcObj = @import("object.zig");

const ValueTag = enum(u8) {
    int,
    bool,
    object,
};

tag: ValueTag,
data: Data,

const Data = union(ValueTag) {
    int: i32,
    bool: bool,
    object: *GcObj,
};
