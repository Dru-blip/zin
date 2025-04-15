const GcObj = @import("object.zig").GcObj;

const ValueTag = enum(u8) {
    int,
    object,
};

pub const Value = struct {
    tag: ValueTag,
    data: Data,

    const Data = union(ValueTag) {
        int: i32,
        object: *GcObj,
    };
};
