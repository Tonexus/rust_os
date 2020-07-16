fn main() {
    println!("cargo:rerun-if-changed=src/std.c");
    cc::Build::new().file("src/std.c").compile("std");
}
