#![feature(lang_items, asm)]
#![no_std]
#![crate_name="kernel"]

use arch::io::serial;

#[cfg(target_arch="x86_64")] #[path="arch/x86_64/mod.rs"]
mod arch;

#[macro_use]
mod logger;

pub mod mem;

#[lang="start"]
#[no_mangle]
pub fn kmain()
{
    logger::init(serial::init(0x3f8));
    info!("Welcome to quantum");

    loop {}
}

#[lang="panic_fmt"]
#[no_mangle]
pub extern "C" fn rust_begin_unwind(msg: ::core::fmt::Arguments, file: &str, line: u32) -> !
{
    // fallback on serial if no logger is set
    if !logger::is_init() {
        logger::init(serial::init(0x3f8));
    }

    logger::_print(format_args!("[PANIC] '{}:{}': {}\n", file, line, msg));

    loop {}
}

#[lang="eh_personality"]
#[no_mangle]
pub fn eh_personality() {}

#[allow(non_snake_case)]
#[no_mangle]
pub extern fn __Unwind_Resume() -> !
{
    loop {}
}
