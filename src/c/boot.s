.extern kmain

// multiboot header for grub bootloader
.set ALIGN,	1 << 0	// align loaded modules on page boundaries
.set MEMINFO,	1 << 1	// provide memory map
.set MAGIC,	0x1BADB002
.set FLAGS, ALIGN | MEMINFO
.set CHECKSUM, -(MAGIC + FLAGS)

.section .multiboot
.align 4
.long MAGIC
.long FLAGS
.long CHECKSUM

.section .bss
// allocate 4KB for stack
.align 16
stack_bottom:
.skip 4096
stack_top:

.section .text
.global start
// actual code
start:
	// set up stack
	mov	$stack_top, %esp
	call	kmain

// hang if kmain ever returns
hang:
	cli		// disable CPU interrupts
	hlt		// halt CPU
	jmp	hang	// if fail, try again

