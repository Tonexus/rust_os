fn main() {
    cc::Build::new().file("src/c/std.s").compile("std");
}
