pub fn read_cr2() usize {
  var value: usize = 0;
  asm volatile("mov %%cr2, %[ret]" : [ret] "=r" (value));
  return value;
}

pub fn halt() void {
  asm volatile("hlt");
}