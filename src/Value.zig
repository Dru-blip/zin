const GcObj = @import("object.zig");

const ValueTag = enum(u8) {
    int,
    object,
};

tag: ValueTag,
data: Data,

const Data = union(ValueTag) {
    int: i32,
    object: *GcObj,
};
