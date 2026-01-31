const manager = @import("manager.zig");
const mem = @import("../mm/index.zig");

pub const Process = struct {
    id: usize,
    name: []const u8,
    ref_count: usize,
    page_directory: usize,

    parent: ?*Process,
    first_child: ?*Process,
    next_sibling: ?*Process,
};

pub fn fork(parent: *Process) !usize {
    const pml4_clone = try mem.clone_pml4(parent.page_directory);
    
    const new_process = try manager.create_process(parent.name, pml4_clone);
    new_process.parent = parent;

    if(!parent.first_child)  {
        parent.first_child = new_process;
        return new_process.id;
    }

    var last_sibling = get_last_sibling(parent);
    last_sibling.next_sibling = new_process;
    return new_process.id;
}

fn get_last_sibling(process: *Process) *Process {
    var current = process.next_sibling;
    while(current) |c| {
        current = c.next_sibling;
    }
    return current;
}