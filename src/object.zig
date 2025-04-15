/// tag to identify the type of object
const ObjTag = enum(u8) {
    list,
    map,
    class,
    module,
    function,
    string,
    instance,
};

/// garbage collected object
pub const GcObj = struct {
    tag: ObjTag,
    next: *GcObj,
};
