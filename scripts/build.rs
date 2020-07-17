fn main() {
    println!("cargo:rerun-if-changed=src/std.c");
    cc::Build::new().file("src/c/std.c").compile("std");
}
