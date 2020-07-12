#![no_std]

mod vga_terminal;

use core::panic::PanicInfo;

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    loop {}
}

// rust entry point
#[no_mangle]
pub extern "C" fn kmain() -> ! {
    vga_terminal::print_something();

    loop {}
}
