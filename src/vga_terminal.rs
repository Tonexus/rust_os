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
    chars: [[VgaChar; BUFFER_W]; BUFFER_H],
}

pub struct Terminal {
    column: usize,
    color: ColorCode,
    buffer: &'static mut VgaBuffer,
}

impl Terminal {
    pub fn clear(&mut self) {
        for i in 0..BUFFER_H {
            for j in 0..BUFFER_W {
                self.buffer.chars[i][j] = VgaChar {
                    ascii: b' ',
                    color: self.color,
                }
            }
        }
    }

    fn new_line(&mut self) {
        // TODO
    }

    pub fn print_char(&mut self, byte: u8) {
        match byte {
            b'\n' => self.new_line(),
            byte => {
                if self.column >= BUFFER_W {
                    self.new_line();
                }

                self.buffer.chars[BUFFER_H-1][self.column] = VgaChar {
                    ascii: byte,
                    color: self.color,
                };
                self.column += 1;
            }
        }
    }

    pub fn print_str(&mut self, s: &str) {
        for byte in s.bytes() {
            self.print_char(byte);
        }
    }
}

pub fn print_something() {
    let mut terminal = Terminal {
        column: 0,
        color: ColorCode::new(Color::White, Color::Black),
        buffer: unsafe { &mut *(0xb8000 as *mut VgaBuffer) },
    };
    terminal.clear();
    terminal.print_str("Hello world!");
}

