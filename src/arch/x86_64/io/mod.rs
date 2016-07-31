#![allow(dead_code)]
pub mod serial;

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

#[inline]
pub unsafe fn outw(port: u16, val: u16) {
    asm!("outb %ax, %dx" : : "{ax}"(val), "{dx}"(port));
}

#[inline]
pub unsafe fn inw(port: u16) -> u16 {
    let ret: u16;
    asm!("inb %dx, %ax" : "={ax}"(ret) : "{dx}"(port));
    ret
}

#[inline]
pub unsafe fn outd(port: u16, val: u32) {
    asm!("outb %eax, %dx" : : "{eax}"(val), "{dx}"(port));
}

#[inline]
pub unsafe fn ind(port: u16) -> u32 {
    let ret: u32;
    asm!("inb %dx, %eax" : "={eax}"(ret) : "{dx}"(port));
    ret
}
