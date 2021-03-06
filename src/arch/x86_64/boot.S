KERNEL_BASE = 0xFFFFFFFF80000000
# Declare Multiboot 2 header in a special section
# Multiboot 2 is needed to load 64bit kernel
.section .multiboot
mbStart:
    .align 8
    .long 0xe85250d6
    .long 0
    .long mbEnd - mbStart
    .long  -(0xe85250d6 + 0 + (mbEnd - mbStart))
    .short 0
    .short 0
    .long 8
mbEnd:

.section .inittext, "ax"
.global start
.code32
start:
    mov $(stack_top - KERNEL_BASE), %esp

    call clear

    # Check that a multiboot2 complient bootloader loaded the kernel
    cmp $0x36d76289, %eax
    jne .noMultiboot

    # Check CPUID for extended processor info support
    mov $0x80000000, %eax
    cpuid
    test $0x80000001, %eax
    jb .noCPUID

    # Check long mode support, bit 29 of the extended processor infos
    mov $0x80000001, %eax
    cpuid
    test $(1<<29), %edx
    jz .noLongMode

    # Long mode capable processor should support at least SSE & SSE2
    mov $0x1, %eax
    cpuid
    test $(1<<25), %edx
    jz .noSSE

    # Enable SSE because libcore needs it
    mov %cr0, %eax
    and $0xfb, %al              # clear coprocessor emulation CR0.EM (bit 2)
    or $(1<<1), %al             # set coprocessor monitoring CR0.MP (bit 1)
    mov %eax, %cr0
    mov %cr4, %eax
    or $(1<<9 | 1<<10), %eax    # set CR4.OSFXSR and CR4.OSXMMEXCPT (bit 9 & 10)
    mov %eax, %cr4

    # Enable page address extension and page size extension for 64bit adresses and 2 MiB pages
    mov %cr4, %eax
    or $(1<<4 | 1<<5), %eax     # set CR4.PAE and CR4.PSE (bit 4 & 5)
    mov %eax, %cr4

    # Load the address of the root page table into CR3
    mov $(pml4t - KERNEL_BASE), %eax
    mov %eax, %cr3

    # Load EFER MSR and set Long Mode Enable (LME bit 8)
    mov $0xC0000080, %ecx
    rdmsr
    or $(1<<8), %eax
    wrmsr

    # Enable paging and write protect CR0.PG and CR0.WP (bit 31 & 16)
    mov %cr0, %eax
    or $(1<<31 | 1<<16), %eax
    mov %eax, %cr0

    # We are now in IA32e submode
    # Load GDT and switch to 64bit mode
    lgdt gdtptr - KERNEL_BASE
    ljmp $0x8, $start64


.noMultiboot:
    mov '0', %al
    jmp error

.noCPUID:
    mov '1', %al
    jmp error

.noLongMode:
    mov '2', %al
    jmp error

.noSSE:
    mov '3', %al
    jmp error

error:
    movw $0x400 | 'E', 0xb8000
    movw $0x400 | 'R', 0xb8002
    movw $0x400 | 'R', 0xb8004
    movw $0x400 | ':', 0xb8006
    mov $0x4, %ah
    mov %ax, 0xb8008
    hlt

clear:
    pusha
    mov $0x0f | ' ', %ax
    mov $0xb8000, %edi
    mov $(25*80), %cx
    rep stosw
    popa
    ret

.code64
.global start64
start64:
    lgdt gdtptr_high
    mov $start64_high, %rax
    jmp *%rax

.section .text
.extern kmain
.globl start64_high
start64_high:
    # Clear the initial low identity map
    mov $0, %rax
    mov %rax, pml4t
    mov %rax, pdpt

    # Set up segment registers
    mov $0x10, %ax
    mov %ax, %ss
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs

    # Set stack pointer
    mov $stack_top, %rsp

    # Call the real Rust kernel
    call kmain

    # Loop in case we ever return (which should never happen)
start64_high.loop:
    hlt
    jmp start64_high.loop

# Page tables with identity paging for the first 4MB
# All identity pages are marked present (1) + writeable (2)
.section .padata
pml4t:
    .quad pdpt - KERNEL_BASE + 3
    .rept 512 - 2
        .quad 0
    .endr
    .quad pdpt - KERNEL_BASE + 3
pdpt:
    .quad pdt - KERNEL_BASE + 3
    .rept 512 - 3
        .quad 0
    .endr
    .quad pdt - KERNEL_BASE + 3
    .quad 0
pdt:
    # Using 2MB pages via page size extension (PSE 0x80)
    .quad 0x000000 + 0x80 + 3
    .quad 0x200000 + 0x80 + 3
    .rept 512 - 2
        .quad 0
    .endr

# setup a temporary stack
stack_bottom:
.skip 16384 # 16KiB
stack_top:

# GDT with 64bit flag set in code and data selectors
.section .data
.globl gdt
gdt:
    # NULL entry
    .quad 0
    # Code segment
    .long 0
    .byte 0
    .byte 0b10011010
    .byte 0b00100000
    .byte 0
    # Data segment
    .long 0
    .byte 0
    .byte 0b10010010
    .byte 0b00100000
    .byte 0
gdtptr:
    .word gdtptr - gdt - 1
    .long gdt - KERNEL_BASE
gdtptr_high:
    .word gdtptr - gdt - 1
    .quad gdt
