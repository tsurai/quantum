ENTRY(start)
OUTPUT_FORMAT(elf64-x86-64)

KERNEL_BASE = 0xFFFFFFFF80000000;

SECTIONS
{
    /* Begin putting sections at 1 MiB, a conventional place for kernels to be
       loaded at by the bootloader. */
    . = 1M;

    . += SIZEOF_HEADERS;

    .init : AT(ADDR(.init))
    {
        KEEP(*(.multiboot))
        *(.inittext)
    }

    /* We want to move the kernel to 0xFFFFFFFFF8000000 */
    . += KERNEL_BASE;

    .text ALIGN(4K) : AT(ADDR(.text) - KERNEL_BASE)
    {
       *(.text)
    }

    /* Read-only data. */
    .rodata ALIGN(4K) : AT(ADDR(.rodata) - KERNEL_BASE)
    {
        *(.rodata)
    }

    /* Read-write data (initialized) */
    .data ALIGN(4K) : AT(ADDR(.data) - KERNEL_BASE)
    {
        *(.padata)
        *(.data)
    }

    /* Read-write data (uninitialized) and stack */
    .bss : AT(ADDR(.bss) - KERNEL_BASE)
    {
        *(.bss)
    }
}
