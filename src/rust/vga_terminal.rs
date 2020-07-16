// basic vga text driver
// exposes vga_print and vga_printl macros for basic formatted print
// exposes vga_

use core::fmt;
use log::{Record, Level, Metadata, SetLoggerError, LevelFilter};
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
    const fn new(bg: Color, fg: Color) -> ColorCode {
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
const TAB_W: usize = 4;
const COLOR_DEFAULT: ColorCode = ColorCode::new(Color::Black, Color::White);
const COLOR_ERROR: ColorCode = ColorCode::new(Color::Black, Color::Red);
const COLOR_WARN: ColorCode = ColorCode::new(Color::Black, Color::Yellow);
const COLOR_DEBUG: ColorCode = ColorCode::new(Color::Black, Color::Green);
const COLOR_TRACE: ColorCode = ColorCode::new(Color::Black, Color::Blue);

#[repr(transparent)]
struct VgaBuffer {
    chars: [[Volatile<VgaChar>; BUFFER_W]; BUFFER_H],
}

pub struct Terminal {
    row: usize,
    col: usize,
    buffer: &'static mut VgaBuffer,
}

impl Terminal {
    fn clear(&mut self) {
        for i in 0..BUFFER_H {
            for j in 0..BUFFER_W {
                self.buffer.chars[i][j].write(VgaChar {
                    ascii: b' ',
                    color: COLOR_DEFAULT,
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
                    color: COLOR_DEFAULT,
                });
            }
        }
    }

    fn tab(&mut self) {
        self.col = (self.col / TAB_W + 1) * TAB_W;
        if self.col >= BUFFER_W {
            self.new_line();
        }
    }

    fn print_char(&mut self, byte: u8, color: ColorCode) {
        match byte {
            b'\n' => self.new_line(),
            b'\t' => self.tab(),
            byte => {
                if self.col >= BUFFER_W {
                    self.new_line();
                }

                self.buffer.chars[self.row][self.col].write(VgaChar {
                    ascii: byte,
                    color: color,
                });
                self.col += 1;
            }
        }
    }

    fn print_str(&mut self, s: &str, color: ColorCode) {
        for byte in s.bytes() {
            self.print_char(byte, color);
        }
    }
}

impl fmt::Write for Terminal {
    fn write_str(&mut self, s: &str) -> fmt::Result {
        self.print_str(s, COLOR_DEFAULT);
        Ok(())
    }
}

lazy_static! {
    pub static ref TERMINAL: Mutex<Terminal> = Mutex::new({
        let t = Terminal {
            row: 0,
            col: 0,
            buffer: unsafe { &mut *(0xb8000 as *mut VgaBuffer) },
        };
        t
    });
}

struct TerminalLogger;

impl log::Log for TerminalLogger {
    fn enabled(&self, metadata: &Metadata) -> bool {
        metadata.level() <= Level::Info
    }

    fn log(&self, record: &Record) {
        use core::fmt::Write;
        if self.enabled(record.metadata()) {
            let mut terminal = TERMINAL.lock();
            let (label, color) = match record.level() {
                log::Level::Error => ("ERROR", COLOR_ERROR),
                log::Level::Warn  => ("WARN ", COLOR_WARN),
                log::Level::Info  => ("INFO ", COLOR_DEFAULT),
                log::Level::Debug => ("DEBUG", COLOR_DEBUG),
                log::Level::Trace => ("TRACE", COLOR_TRACE),
            };
            terminal.print_char(b'[', COLOR_DEFAULT);
            terminal.print_str(label, color);
            terminal.write_fmt(format_args!("]: {}", record.args())).unwrap();
        }
    }

    fn flush(&self) {}
}

static LOGGER: TerminalLogger = TerminalLogger;

pub fn init_logger() -> Result<(), SetLoggerError> {
    log::set_logger(&LOGGER).map(|()| log::set_max_level(LevelFilter::Info))
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

