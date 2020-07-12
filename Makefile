CC := i686-elf-gcc
AS := $(CC)
ASFLAGS := -std=gnu99 -ffreestanding -c
LDFLAGS := -ffreestanding -nostdlib -lgcc -Ttext 0x1000000

BUILD := build
SRC := src

target := i686-rust-os.json
rust_srcs := $(wildcard $(SRC)/*.rs)
kernel_rust := target/i686-rust-os/debug/librust_os.a
asm_srcs := $(wildcard $(SRC)/*.s)
asm_objs := $(patsubst $(SRC)/%.s, $(BUILD)/%.o, $(asm_srcs))
link_src := $(SRC)/linker.ld
kernel := $(BUILD)/kernel.elf

.PHONY: all run rust clean

all: $(kernel)

run: $(kernel)
	qemu-system-i386 -kernel $(kernel)

$(kernel): $(kernel_rust) $(asm_objs) $(link_src)
	$(CC) $(LDFLAGS) -T $(link_src) $(asm_objs) $(kernel_rust) -o $(kernel)

$(BUILD)/%.o: $(SRC)/%.s $(BUILD)
	$(AS) $(ASFLAGS) $< -o $@

$(BUILD):
	mkdir -p $(BUILD)/

rust: $(kernel_rust)

$(kernel_rust): $(rust_srcs) $(target)
	cargo xbuild --target $(target)

clean:
	rm -rf $(BUILD)/ target/
