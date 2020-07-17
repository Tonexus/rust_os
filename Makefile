CC := i686-elf-gcc
CFLAGS := -std=gnu99 -ffreestanding -flto -O3 -Wall -c
AS := $(CC)
ASFLAGS := $(CFLAGS)
AR := $(CC)-ar
ARFLAGS := rcs
LDFLAGS := -ffreestanding -flto -nostdlib -lgcc -Ttext 0x1000000

C_SRC := src/c
RUST_SRC := src/rust
BUILD := build
RUST_ASM := $(BUILD)/rust
SCRIPTS := scripts

target := i686-rust-os.json
inject_asm := $(SCRIPTS)/inject_asm.py
rust_meta := Cargo.toml $(SCRIPTS)/build.rs
rust_srcs := $(wildcard $(RUST_SRC)/*.rs)
kernel_rust := $(BUILD)/rust.a
asm_srcs := $(wildcard $(C_SRC)/*.s)
asm_objs := $(patsubst $(C_SRC)/%.s, $(BUILD)/%.o, $(asm_srcs))
c_std_src := $(C_SRC)/std.s # needs to be linked into rust
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
	cargo clean
	rm -rf $(BUILD) Cargo.lock

# builds elf kernel from object files

$(kernel): $(kernel_rust) $(asm_objs) $(c_objs) $(link_src)
	@mkdir -p $(@D)
	$(CC) $(LDFLAGS) -T $(link_src) $(asm_objs) $(c_objs) -o $(kernel) $(kernel_rust)

# builds object files from rust

$(kernel_rust): $(rust_srcs) $(c_std_src) $(rust_meta) $(inject_asm) $(target)
	@cargo clean
	@mkdir -p $(@D)
	@mkdir -p $(RUST_ASM)
	RUSTFLAGS="--emit asm" cargo build -Z build-std=core --release --target $(target)
	python3 $(inject_asm) target/i686-rust-os/release/deps/*.s $(RUST_ASM)
	@for file in $(RUST_ASM)/*.s; do \
		echo "$(AS) $(ASFLAGS) $$file -o $${file%.s}.o"; \
		$(AS) $(ASFLAGS) $$file -o $${file%.s}.o; \
	done
	$(AR) $(ARFLAGS) $(kernel_rust) $(RUST_ASM)/*.o

$(BUILD)/%.o: $(C_SRC)/%.s
	@mkdir -p $(@D)
	$(AS) $(ASFLAGS) $< -o $@

$(BUILD)/%.o: $(C_SRC)/%.c
	@mkdir -p $(@D)
	$(CC) $(CFLAGS) $< -o $@

