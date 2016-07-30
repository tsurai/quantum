pub use self::serial::{serial, Serial};

mod serial;

#[inline]
pub unsafe fn outb(port: u16, val: u8) {
    asm!("outb %al, %dx" : : "{al}"(val), "{dx}"(port));
}

#[inline]
pub unsafe fn inb(port: u16) -> u8 {
    let ret: u8;
    asm!("inb %dx, %al" : "={al}"(ret) : "{dx}"(port));
    ret
}
