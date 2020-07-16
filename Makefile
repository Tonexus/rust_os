CC := i686-elf-gcc
CFLAGS := -std=gnu99 -ffreestanding -c
AS := $(CC)
ASFLAGS := -std=gnu99 -ffreestanding -c
LDFLAGS := -ffreestanding -nostdlib -lgcc -Ttext 0x1000000

SRC := src
BUILD := build

target := i686-rust-os.json
rust_meta := Cargo.toml build.rs
rust_srcs := $(wildcard $(SRC)/*.rs)
kernel_rust := target/i686-rust-os/debug/librust_os.a
asm_srcs := $(wildcard $(SRC)/*.s)
asm_objs := $(patsubst $(SRC)/%.s, $(BUILD)/%.o, $(asm_srcs))
c_std_src := $(SRC)/std.c # Needs to be linked into rust
c_srcs := $(wildcard $(SRC)/*.c)
c_objs := $(patsubst $(SRC)/%.c, $(BUILD)/%.o, $(c_srcs))
link_src := $(SRC)/linker.ld
kernel := $(BUILD)/kernel.elf

.PHONY: all run rust rust_objs clean

$(BUILD):
	mkdir -p $(BUILD)/

all: $(kernel)

run: $(kernel)
	qemu-system-i386 -kernel $(kernel)

$(kernel): rust_objs $(asm_objs) $(c_objs) $(link_src)
	$(CC) $(LDFLAGS) -T $(link_src) $(BUILD)/*.o -o $(kernel)

rust_objs: $(kernel_rust) $(BUILD)
	for file in target/i686-rust-os/debug/deps/*.s; do \
		echo "TODO modify assembly for $$file"; \
		no_path="$${file##*/}"; \
		$(AS) $(ASFLAGS) "$$file" -o "$(BUILD)/$${no_path%s}o"; \
	done

$(kernel_rust): $(rust_srcs) $(rust_meta) $(c_std_src) $(target)
	RUSTFLAGS="--emit asm" cargo build -Z build-std=core --target $(target)

$(BUILD)/%.o: $(SRC)/%.s $(BUILD)
	$(AS) $(ASFLAGS) $< -o $@

$(BUILD)/%.o: $(SRC)/%.c $(BUILD)
	$(CC) $(CFLAGS) $< -o $@

clean:
	rm -rf $(BUILD)/ target/
