use core::fmt::{self, Write};
use arch::io;

/*
 * inner should be an implementation of the fmt::Write trait
 * but the lack of memory management and heap allocation makes
 * the usage of unsized types impossible right now
 */
static mut LOGGER: Logger = Logger{inner: None};

#[allow(dead_code)]
pub enum Level {
    FATAL,
    ERROR,
    WARNING,
    INFO,
    DEBUG,
    TRACE
}

impl fmt::Display for Level {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        let s = match *self {
            Level::FATAL => "FATA",
            Level::ERROR => "ERRO",
            Level::WARNING => "WARN",
            Level::INFO => "INFO",
            Level::DEBUG => "DEBU",
            Level::TRACE => "TRAC"
        };
        write!(f, "{}", s)
    }
}

#[doc(hidden)]
pub fn _print(fmt: fmt::Arguments)
{
    get().write_fmt(fmt).map_err(|e| panic!("failed printing to logger: {}", e)).ok();
}

pub struct Logger {
    inner: Option<io::serial::Serial>
}

pub fn init(inner: io::serial::Serial) {
    unsafe {
        LOGGER.inner = Some(inner);
    }
}

pub fn is_init() -> bool {
    unsafe {
        LOGGER.inner.is_some()
    }
}

pub fn get<'a>() -> &'a mut Logger {
    unsafe {
        &mut LOGGER
    }
}

impl fmt::Write for Logger {
    fn write_str(&mut self, s: &str) -> fmt::Result {
        self.inner.as_mut().map_or(Err(fmt::Error), |x| x.write_str(s))
    }

    fn write_char(&mut self, c: char) -> fmt::Result {
        self.inner.as_mut().map_or(Err(fmt::Error), |x| x.write_char(c))
    }

    fn write_fmt(&mut self, args: fmt::Arguments) -> fmt::Result {
        self.inner.as_mut().map_or(Err(fmt::Error), |x| x.write_fmt(args))
    }
}


#[doc(hidden)]
macro_rules! _log {
    ($lvl:expr, $fmt:expr) => ({
        $crate::logger::_print(format_args!(concat!("[{}] ", $fmt, "\n"), $lvl))
    });
    ($lvl:expr, $fmt:expr, $($arg:tt)*) => ({
        $crate::logger::_print(format_args!(concat!("[{}] ", $fmt, "\n"), $lvl, $($arg)*))
    });
}

#[macro_export]
macro_rules! crit {
    ($($arg:tt)*) => (
        _log!($crate::logger::Level::FATAL, $($arg)*)
    );
}

#[macro_export]
macro_rules! err {
    ($($arg:tt)*) => (
        _log!($crate::logger::Level::ERROR, $($arg)*)
    );
}

#[macro_export]
macro_rules! warn {
    ($($arg:tt)*) => (
        _log!($crate::logger::Level::WARNING, $($arg)*)
    );
}

#[macro_export]
macro_rules! info {
    ($($arg:tt)*) => (
        _log!($crate::logger::Level::INFO, $($arg)*)
    );
}

#[macro_export]
macro_rules! debug {
    ($($arg:tt)*) => ({
        _log!($crate::logger::Level::DEBUG, $($arg)*)
    });
}

#[macro_export]
macro_rules! trace {
   ($fmt:expr, $($arg:tt)*) => ({
       _log!($crate::logger::Level::TRACE, concat!(file!(), ":", line!(), ": ", $fmt), $($arg)*)
   });
   ($($arg:tt)*) => ({
       _log!($crate::logger::Level::TRACE, concat!(file!(), ":", line!(), ": {}"), $($arg)*)
   });
}
