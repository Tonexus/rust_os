#![no_std]

mod vga_terminal;

use core::panic::PanicInfo;

#[panic_handler]
fn panic(info: &PanicInfo) -> ! {
    vga_println!("{}", info);
    loop {}
}

// rust entry point
#[no_mangle]
pub extern "C" fn kmain() -> ! {
    vga_clear!();
    vga_println!("I have {} {}", 5, "cats");
    panic!("Bad");

    loop {}
}
