/// tag to identify the type of object
pub const ObjTag = enum(u8) {
    list,
    map,
    class,
    module,
    function,
    string,
    instance,
};

const GcObject = @This();

tag: ObjTag,
next: *GcObject,
