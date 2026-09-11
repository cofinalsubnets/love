// the whole build door: one archive, no linker script, no bindgen. b/liblv.a is
// laid by i/lib/Makefile; a released crate would carry the tree and drive that
// make here instead of reading a path out of the environment.
fn main() {
    let dir = std::env::var("LOVE_LIB_DIR").unwrap_or_else(|_| "../../../b".into());
    println!("cargo:rustc-link-search=native={dir}");
    println!("cargo:rustc-link-lib=static=lv");
    // the nif section's __start/__stop bracket: --gc-sections drops love_nifs
    // where nothing keeps it, and lld then leaves the pair undefined. see the
    // README -- the alternative is `retain` on the LvNif macro in l/love.h.
    println!("cargo:rustc-link-arg=-Wl,-z,nostart-stop-gc");
    println!("cargo:rerun-if-changed={dir}/liblv.a");
}
