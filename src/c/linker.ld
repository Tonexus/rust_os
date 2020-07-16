/* points to bootlader entry point*/
ENTRY(start)

SECTIONS {
	. = 1M;

	/* multiboot header */
	.rodata BLOCK(4K) : ALIGN(4K) {
		*(.multiboot)
	}

	/* code */
	.text BLOCK(4K) : ALIGN(4K) {
		*(.text)
	}

	/* read-only data */
	.rodata BLOCK(4K) : ALIGN(4K) {
		*(.data)
	}

	/* read/write-data (initialized) */
	.data BLOCK(4K) : ALIGN(4K) {
		*(.data)
	}

	/* read/write-data (uninitialized) */
	.bss BLOCK(4K) : ALIGN(4K) {
		*(COMMON)
		*(.bss)
	}
}
