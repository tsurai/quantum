use core::fmt;
use super::{outb, inb};

pub struct Serial {
    port: u16
}

pub fn init(port: u16) -> Serial {
    Serial {
        port: port
    }
}

impl fmt::Write for Serial {
    fn write_str(&mut self, s: &str) -> fmt::Result {
        for b in s.bytes() {
            self.write_char(b as char).unwrap()
        }
        Ok(())
    }

    fn write_char(&mut self, c: char) -> fmt::Result {
        unsafe {
            while (inb(self.port+5) & 0x20) == 0 {};
            outb(self.port, c as u8);
        }
        Ok(())
    }

    fn write_fmt(&mut self, args: fmt::Arguments) -> fmt::Result {
        fmt::write(self, args)
    }
}

