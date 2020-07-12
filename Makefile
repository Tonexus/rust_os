CC := i686-elf-gcc
AS := $(CC)
ASFLAGS := -std=gnu99 -ffreestanding -c
LDFLAGS := -ffreestanding -nostdlib -lgcc -Ttext 0x1000000

target := i686-rust-os.json
kernel := build/kernel.elf
kernel_rust := target/i686-rust-os/debug/librust_os.a
asm_srcs := $(wildcard src/*.s)
asm_objs := $(patsubst src/%.s, build/%.o, $(asm_srcs))

.PHONY: kernel_rust build

build: $(kernel)

$(kernel): $(kernel_rust) $(asm_objs) src/linker.ld
	$(CC) $(LDFLAGS) -T src/linker.ld $(asm_objs) $(kernel_rust) -o $(kernel)

build/%.o: src/%.s
	$(AS) $(ASFLAGS) $< -o $@

kernel_rust: $(kernel_rust)

$(kernel_rust): src/lib.rs $(target)
	cargo xbuild --target $(target)

