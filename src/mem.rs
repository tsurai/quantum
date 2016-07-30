#![no_builtins]
#![allow(dead_code)]

#[no_mangle]
pub unsafe extern fn memcpy(dest: *mut u8, src: *const u8, n: usize) -> *mut u8 {
    for i in 0..n as isize {
        *dest.offset(i) = *src.offset(i);
    }
    dest
}

#[no_mangle]
pub unsafe extern fn memset(s: *mut u8, c: i32, n: usize) -> *mut u8 {
    for i in 0..n as isize {
        *s.offset(i) = c as u8;
    }
    s
}

#[no_mangle]
pub unsafe extern fn memcmp(s1: *const u8, s2: *const u8, n: usize) -> i32 {
    for i in 0..n as isize {
        let a = *s1.offset(i);
        let b = *s2.offset(i);
        if a != b {
            return a as i32 - b as i32
        }
    }
    0
}
