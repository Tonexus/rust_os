#![no_std]

mod vga_terminal;

use core::panic::PanicInfo;

#[panic_handler]
fn panic(info: &PanicInfo) -> ! {
    log::error!("{}", info);
    loop {}
}

// rust kernel entry point
#[no_mangle]
pub extern "C" fn kmain() -> ! {
    vga_terminal::init_logger().unwrap();
    vga_clear!();
    log::info!("Kernel has started up\n");
    vga_println!("I have {} {}", 5, "cats");
    panic!("ded");
}
