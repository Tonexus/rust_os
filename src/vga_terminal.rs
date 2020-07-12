// basic vga text driver

use core::fmt;
use volatile::Volatile;
use spin::Mutex;
use lazy_static::lazy_static;

#[allow(dead_code)]
#[derive(Copy, Clone, Debug, PartialEq, Eq)]
#[repr(u8)]
pub enum Color {
    Black = 0,
    Blue = 1,
    Green = 2,
    Cyan = 3,
    Red = 4,
    Magenta = 5,
    Brown = 6,
    LightGray = 7,
    DarkGray = 8,
    LightBlue = 9,
    LightGreen = 10,
    LightCyan = 11,
    LightRed = 12,
    Pink = 13,
    Yellow = 14,
    White = 15,
}

#[derive(Copy, Clone, Debug, PartialEq, Eq)]
#[repr(transparent)]
struct ColorCode(u8);

impl ColorCode {
    fn new(fg: Color, bg: Color) -> ColorCode {
        ColorCode((bg as u8) << 4 | (fg as u8))
    }
}

#[derive(Copy, Clone, Debug, PartialEq, Eq)]
#[repr(C)]
struct VgaChar {
    ascii: u8,
    color: ColorCode,
}

const BUFFER_H: usize = 25;
const BUFFER_W: usize = 80;

#[repr(transparent)]
struct VgaBuffer {
    chars: [[Volatile<VgaChar>; BUFFER_W]; BUFFER_H],
}

pub struct Terminal {
    row: usize,
    col: usize,
    color: ColorCode,
    buffer: &'static mut VgaBuffer,
}

impl Terminal {
    pub fn clear(&mut self) {
        for i in 0..BUFFER_H {
            for j in 0..BUFFER_W {
                self.buffer.chars[i][j].write(VgaChar {
                    ascii: b' ',
                    color: self.color,
                });
            }
        }
    }

    fn new_line(&mut self) {
        self.row += 1;
        self.col = 0;
        if self.row >= BUFFER_H {
            for i in 0..BUFFER_H-1 {
                for j in 0..BUFFER_W {
                    self.buffer.chars[i][j].write(self.buffer.chars[i+1][j].read());
                }
            }
            for j in 0..BUFFER_W {
                self.buffer.chars[BUFFER_H-1][j].write(VgaChar {
                    ascii: b' ',
                    color: self.color,
                });
            }
        }
    }

    pub fn print_char(&mut self, byte: u8) {
        match byte {
            b'\n' => self.new_line(),
            byte => {
                if self.col >= BUFFER_W {
                    self.new_line();
                }

                self.buffer.chars[self.row][self.col].write(VgaChar {
                    ascii: byte,
                    color: self.color,
                });
                self.col += 1;
            }
        }
    }

    pub fn print_str(&mut self, s: &str) {
        for byte in s.bytes() {
            self.print_char(byte);
        }
    }
}

impl fmt::Write for Terminal {
    fn write_str(&mut self, s: &str) -> fmt::Result {
        self.print_str(s);
        Ok(())
    }
}

lazy_static! {
    pub static ref TERMINAL: Mutex<Terminal> = Mutex::new(Terminal {
        row: 0,
        col: 0,
        color: ColorCode::new(Color::White, Color::Black),
        buffer: unsafe { &mut *(0xb8000 as *mut VgaBuffer) },
    });
}

#[doc(hidden)]
pub fn _vga_print(args: fmt::Arguments) {
    use core::fmt::Write;
    TERMINAL.lock().write_fmt(args).unwrap();
}

#[doc(hidden)]
pub fn _vga_clear() {
    TERMINAL.lock().clear();
}

#[macro_export]
macro_rules! vga_print {
    ($($arg:tt)*) => ($crate::vga_terminal::_vga_print(format_args!($($arg)*)));
}

#[macro_export]
macro_rules! vga_println {
    () => ($crate::vga_print!("\n"));
    ($($arg:tt)*) => ($crate::vga_print!("{}\n", format_args!($($arg)*)));
}

#[macro_export]
macro_rules! vga_clear {
    () => ($crate::vga_terminal::_vga_clear());
}

