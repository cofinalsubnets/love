// the whole build door: one archive, no linker script, no bindgen. b/liblv.a is
// laid by i/lib/Makefile; a released crate would carry the tree and drive that
// make here instead of reading a path out of the environment.
fn main() {
    let dir = std::env::var("LOVE_LIB_DIR").unwrap_or_else(|_| "../../../b".into());
    // the object, not an archive: a love_nifs row is referenced by nothing, so an
    // archive member carrying one is never pulled and the __start_/__stop_ bracket
    // comes out undefined. one .o on the link line, and no flags of ours.
    println!("cargo:rustc-link-arg={dir}/liblv.o");
    println!("cargo:rerun-if-changed={dir}/liblv.o");
}
