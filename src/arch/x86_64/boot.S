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

.section .text
.global start
.code32
start:
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

    # Enable paging before switching to long mode
    mov %cr4, %eax
    or $(1<<4 | 1<<5), %eax     # set CR4.PAE and CR4.PSE (bit 4 & 5)
    mov %eax, %cr4

    # Load pml4t into cr3
    mov $pml4t, %eax
    mov %eax, %cr3

    # Load EFER MSR and set Long Mode Enable (LME bit 8)
    mov $0xC0000080, %ecx
    rdmsr
    or $(1<<8), %eax
    wrmsr

    # Enable paging and wrote protect to enter long mode submode IA32e
    mov %cr0, %eax
    or $(1<<31), %eax
    mov %eax, %cr0

    # Load GDT and switch to 64bit mode
    lgdt gdtptr
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
    movw $0x400|'E', 0xb8000
    movw $0x400|'R', 0xb8002
    movw $0x400|'R', 0xb8004
    movw $0x400|':', 0xb8006
    mov $0x4, %ah
    mov %ax, 0xb8008
    hlt


.section .text
.extern kmain
.code64
.globl start64
start64:
    # Clear the interrupt flag until we have a 64bit IDT
    cli

    # Set stack pointer
    mov $stack_top, %rsp

    # Set up segment registers
    mov $0x10, %ax
    mov %ax, %ss
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs

    call kmain

start64.loop:
    hlt
    jmp start64.loop

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
    .quad gdt

# Page tables with identity paging for the first 4MB
# All identity pages are marked present (1) + writeable (2)
.section .padata
pml4t:
    .quad pdpt + 3
    .rept 512 - 1
        .quad 0
    .endr
pdpt:
    .quad pdt + 3
    .rept 512 - 1
        .quad 0
    .endr
pdt:
    # Using 2MB pages via page size extension (PSE 0x80)
    .quad 0x000000 + 0x80 + 3
    .quad 0x200000 + 0x80 + 3
    .rept 512 - 2
        .quad 0
    .endr

# setup a temporary stack
.section .bootstrap_stack, "aw", @nobits
stack_bottom:
.skip 16384 # 16KiB
stack_top:
