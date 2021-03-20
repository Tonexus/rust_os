Kernel written in Rust. Loosely based on the tutorial
[here](https://os.phil-opp.com/). Compile with `make all`. Requires Rust,
i686-elf-gcc, qemu-system-i386, and probably some other things I'm forgetting.

TODO: Come back in 10 years after I've written a low level language that
has all of the memory saftey of rust, but also allows for a segmented stack and
a compiler that inserts estimated stack frame size into the raw machine code.
