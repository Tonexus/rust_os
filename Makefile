CC := i686-elf-gcc
CFLAGS := -std=gnu99 -ffreestanding -O3 -Wall -c
AS := $(CC)
ASFLAGS := $(CFLAGS)
LDFLAGS := -ffreestanding -nostdlib -lgcc -Ttext 0x1000000

C_SRC := src/c
RUST_SRC := src/rust
BUILD := build

target := i686-rust-os.json
rust_meta := Cargo.toml build.rs
rust_srcs := $(wildcard $(RUST_SRC)/*.rs)
kernel_rust := target/i686-rust-os/debug/librust_os.a
asm_srcs := $(wildcard $(C_SRC)/*.s)
asm_objs := $(patsubst $(C_SRC)/%.s, $(BUILD)/%.o, $(asm_srcs))
c_std_src := $(C_SRC)/std.c # needs to be linked into rust
c_srcs := $(wildcard $(C_SRC)/*.c)
c_objs := $(patsubst $(C_SRC)/%.c, $(BUILD)/%.o, $(c_srcs))
link_src := $(C_SRC)/linker.ld
kernel := $(BUILD)/kernel.elf

.PHONY: all run clean

# usual scripts

all: $(kernel)

run: $(kernel)
	qemu-system-i386 -kernel $(kernel)

clean:
	rm -rf $(BUILD) target Cargo.lock

# builds elf kernel from object files

$(kernel): $(kernel_rust) $(asm_objs) $(c_objs) $(link_src)
	@mkdir -p $(@D)
	$(CC) $(LDFLAGS) -T $(link_src) $(BUILD)/*.o -o $(kernel)

# builds object files from rust

$(kernel_rust): $(rust_srcs) $(rust_meta) $(c_std_src) $(target)
	@cargo clean
	RUSTFLAGS="--emit asm" cargo build -Z build-std=core --target $(target)
	@for file in target/i686-rust-os/debug/deps/*.s; do \
		echo "TODO modify assembly for $$file"; \
		no_path="$${file##*/}"; \
		mkdir -p $(BUILD); \
		echo "$(AS) $(ASFLAGS) \"$$file\" -o \"$(BUILD)/$${no_path%s}o\""; \
		$(AS) $(ASFLAGS) "$$file" -o "$(BUILD)/$${no_path%s}o"; \
	done

$(BUILD)/%.o: $(C_SRC)/%.s
	@mkdir -p $(@D)
	$(AS) $(ASFLAGS) $< -o $@

$(BUILD)/%.o: $(C_SRC)/%.c
	@mkdir -p $(@D)
	$(CC) $(CFLAGS) $< -o $@

